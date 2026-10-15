"""Prueba en el emulador desechable de CI. Nunca borra los datos de la agenda."""
import os
import re
import subprocess
import time
from pathlib import Path
import xml.etree.ElementTree as ET

if os.environ.get('GITHUB_ACTIONS') != 'true':
    raise SystemExit('Esta prueba de permisos está reservada al emulador desechable de GitHub Actions.')

PACKAGE = 'com.miagenda.local'
OUT = Path('smoke-results')
OUT.mkdir(exist_ok=True)


def adb(*args):
    return subprocess.check_output(['adb', *args], text=True, stderr=subprocess.STDOUT)


def screen():
    adb('shell', 'uiautomator', 'dump', '/sdcard/agenda-ui.xml')
    content = adb('exec-out', 'cat', '/sdcard/agenda-ui.xml')
    (OUT / 'avisos-ui.xml').write_text(content)
    return ET.fromstring(content[content.index('<?xml'):])


def find_control(label, click=False):
    for attempt in range(8):
        tree = screen()
        nodes = []
        for node in tree.iter('node'):
            text = node.attrib.get('text', '') + ' ' + node.attrib.get('content-desc', '')
            if label not in text:
                continue
            values = list(map(int, re.findall(r'\d+', node.attrib.get('bounds', ''))))
            if len(values) == 4:
                x1, y1, x2, y2 = values
                if x2 > x1 and y2 > y1:
                    nodes.append(((x2-x1)*(y2-y1), values, node.attrib))
        if nodes:
            _, (x1, y1, x2, y2), attributes = min(nodes, key=lambda item: item[0])
            if click:
                assert attributes.get('enabled', 'true') == 'true', label + ' está deshabilitado'
                adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
                time.sleep(1)
            return attributes
        if attempt >= 2 and not label.startswith(('Notificaciones', 'Horario aproximado')):
            adb('shell', 'input', 'swipe', '540', '1600', '540', '600', '400')
        time.sleep(1)
    (OUT / 'avisos-fallo.png').write_bytes(subprocess.check_output(['adb', 'exec-out', 'screencap', '-p']))
    print((OUT / 'avisos-ui.xml').read_text(), flush=True)
    print(adb('shell', 'dumpsys', 'activity', 'activities')[-12000:], flush=True)
    raise AssertionError('No se encontró: ' + label)


def open_settings():
    # La revocación del permiso puede matar el proceso. Abrir por el lanzador y
    # usar la campana visible evita depender de enlaces recibidos al arrancar.
    print(adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/.MainActivity'), flush=True)
    time.sleep(4)
    tree = screen()
    if not any('Avisos y permisos' in node.attrib.get('content-desc', '') + node.attrib.get('text', '') for node in tree.iter('node')):
        create = find_control('Nueva actividad')
        left, top, right, bottom = map(int, re.findall(r'\d+', create['bounds']))
        candidates = []
        for node in screen().iter('node'):
            values = list(map(int, re.findall(r'\d+', node.attrib.get('bounds', ''))))
            if len(values) == 4 and node.attrib.get('class') == 'android.widget.Button':
                x1, y1, x2, y2 = values
                if x1 >= right and y1 < bottom and y2 > top:
                    candidates.append(values)
        assert len(candidates) == 1, 'Debe haber una campana a la derecha de Nueva actividad'
        x1, y1, x2, y2 = candidates[0]
        adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
        time.sleep(2)
    adb('shell', 'input', 'swipe', '540', '500', '540', '1700', '400')
    time.sleep(1)


def notification_contains(title, timeout=35):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        dump = adb('shell', 'dumpsys', 'notification', '--noredact')
        (OUT / 'avisos-entregados.txt').write_text(dump)
        if title in dump and PACKAGE in dump:
            return
        time.sleep(2)
    raise AssertionError('No se entregó: ' + title)


adb('shell', 'pm', 'grant', PACKAGE, 'android.permission.POST_NOTIFICATIONS')
adb('shell', 'appops', 'set', PACKAGE, 'SCHEDULE_EXACT_ALARM', 'allow')
open_settings()
find_control('Notificaciones permitidas')
find_control('Probar aviso ahora', click=True)
notification_contains('Aviso de prueba')
print('OK: notificación inmediata recibida', flush=True)
find_control('Probar aviso en 10 segundos', click=True)
adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
time.sleep(1)
adb('shell', 'am', 'kill', PACKAGE)  # Cierra el proceso; no usa force-stop, que bloquea alarmas por diseño de Android.
notification_contains('Aviso programado de prueba')
print('OK: notificación programada recibida en segundo plano', flush=True)
(OUT / 'aviso-programado.png').write_bytes(subprocess.check_output(['adb', 'exec-out', 'screencap', '-p']))

adb('shell', 'pm', 'revoke', PACKAGE, 'android.permission.POST_NOTIFICATIONS')
open_settings()
find_control('Notificaciones bloqueadas o sin permiso')
print('OK: permiso denegado reflejado en la pantalla', flush=True)
assert 'granted=false' in adb('shell', 'dumpsys', 'package', PACKAGE).split('android.permission.POST_NOTIFICATIONS:')[-1].split('\n')[0]

adb('shell', 'pm', 'grant', PACKAGE, 'android.permission.POST_NOTIFICATIONS')
adb('shell', 'appops', 'set', PACKAGE, 'SCHEDULE_EXACT_ALARM', 'deny')
open_settings()
find_control('Horario aproximado')
adb('shell', 'appops', 'set', PACKAGE, 'SCHEDULE_EXACT_ALARM', 'allow')
# Deja la app en el calendario para la captura visual habitual.
adb('shell', 'am', 'force-stop', PACKAGE)
adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/.MainActivity')
time.sleep(3)
(OUT / 'reapertura.png').write_bytes(subprocess.check_output(['adb', 'exec-out', 'screencap', '-p']))
(OUT / 'AVISOS_RESULTADO.txt').write_text('OK: aviso inmediato, aviso programado con proceso cerrado, permiso denegado y precisión denegada en Android 35.\n')
print('OK: notificación inmediata y programada recibidas; estados de permisos comprobados.')
