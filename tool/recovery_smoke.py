"""Restauración por selector Android con datos sintéticos; conserva la otra app."""
import base64
import os
import re
import sqlite3
import subprocess
import time
from pathlib import Path
import xml.etree.ElementTree as ET

assert os.environ.get('GITHUB_ACTIONS') == 'true', 'Solo emulador desechable de CI'
PACKAGE = 'com.miagenda.recuperacion'
ORIGINAL = 'com.miagenda.local'
OUT = Path('smoke-results')


def adb(*args):
    return subprocess.check_output(['adb', *args], text=True, stderr=subprocess.STDOUT)


def read_db(package):
    return subprocess.check_output(['adb', 'exec-out', 'run-as', package, 'cat', 'files/mi_agenda.sqlite'])


def find(label, click=False):
    for attempt in range(8):
        adb('shell', 'uiautomator', 'dump', '/sdcard/recovery-ui.xml')
        xml = adb('exec-out', 'cat', '/sdcard/recovery-ui.xml')
        (OUT / 'recovery-ui.xml').write_text(xml)
        root = ET.fromstring(xml[xml.index('<?xml'):])
        candidates = []
        for node in root.iter('node'):
            if label in node.attrib.get('text', '') + node.attrib.get('content-desc', ''):
                values = list(map(int, re.findall(r'\d+', node.attrib.get('bounds', ''))))
                if len(values) == 4:
                    x1, y1, x2, y2 = values
                    if x2 > x1 and y2 > y1:
                        candidates.append(((x2-x1)*(y2-y1), values))
        if candidates:
            _, (x1, y1, x2, y2) = min(candidates)
            if click:
                adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
                time.sleep(2)
            return
        time.sleep(1)
    print(xml, flush=True)
    raise AssertionError('No se encontró: ' + label)


fixture = OUT / 'fixture.sqlite'
db = sqlite3.connect(fixture)
db.execute('CREATE TABLE activities (id TEXT PRIMARY KEY, title TEXT, category TEXT, local_date TEXT, minute_of_day INTEGER, notes TEXT, created_at INTEGER, updated_at INTEGER)')
db.execute('CREATE TABLE task_templates (id TEXT PRIMARY KEY, activity_id TEXT REFERENCES activities(id), description TEXT, sort_order INTEGER, is_done INTEGER)')
for i in range(2):
    db.execute('INSERT INTO activities VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (str(i), 'Prueba recuperada ' + str(i), 'work', '2026-10-20', 600+i, 'Nota conservada', 123, 456))
    db.execute('INSERT INTO task_templates VALUES (?, ?, ?, ?, ?)', ('t'+str(i), str(i), 'Pendiente de prueba', 0, i))
db.execute('PRAGMA user_version=1')
db.commit()
db.close()
text_file = OUT / 'MiAgenda-prueba.txt'
text_file.write_text('$ run-as com.miagenda.local base64 files/mi_agenda.sqlite\n' + base64.b64encode(fixture.read_bytes()).decode() + '\n')
adb('push', str(text_file), '/sdcard/Download/MiAgenda-prueba.txt')
adb('shell', 'am', 'force-stop', ORIGINAL)
original = read_db(ORIGINAL)
adb('install', '-r', 'entrega/Mi-Agenda-Recuperacion.apk')
adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.miagenda.local.MainActivity')
time.sleep(6)
# La campana tiene un tooltip. Un enlace de prueba explícito abre Avisos.
adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.VIEW', '-d', 'miagendarecuperacion://app/notifications', '-p', PACKAGE)
time.sleep(3)
find('Respaldo y recuperación', click=True)
find('Seleccionar respaldo', click=True)
find('MiAgenda-prueba.txt', click=True)
find('Respaldo válido: 2 actividades y 2 tareas.')
find('Restaurar en esta agenda vacía', click=True)
find('Restaurar', click=True)
find('Restauración completada: 2 actividades y 2 tareas.')
adb('shell', 'am', 'force-stop', PACKAGE)
restored = OUT / 'restored.sqlite'
restored.write_bytes(read_db(PACKAGE))
db = sqlite3.connect(restored)
assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
assert db.execute('SELECT count(*) FROM activities').fetchone()[0] == 2
assert db.execute('SELECT count(*) FROM task_templates').fetchone()[0] == 2
assert db.execute('SELECT sum(is_done) FROM task_templates').fetchone()[0] == 1
assert db.execute('SELECT notes, minute_of_day, created_at, updated_at FROM activities ORDER BY id').fetchall() == [('Nota conservada', 600, 123, 456), ('Nota conservada', 601, 123, 456)]
db.close()
assert read_db(ORIGINAL) == original, 'Se modificó la agenda anterior'
adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.miagenda.local.MainActivity')
time.sleep(3)
(OUT / 'recuperacion.png').write_bytes(subprocess.check_output(['adb', 'exec-out', 'screencap', '-p']))
print('OK: TXT seleccionado desde Android; restauración 2 actividades/2 tareas; notas, horas, fechas y estados conservados; paquete original sin cambios.', flush=True)
