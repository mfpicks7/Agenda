"""Verifica el SQL real de app_database.dart con SQLite; no sustituye Flutter tests."""
import re
import sqlite3
import tempfile
from pathlib import Path

source = (Path(__file__).resolve().parents[1] / 'lib/core/database/app_database.dart').read_text()
statements = re.findall(r"customStatement\('''(CREATE.*?)'''\)", source, re.S)
statements += re.findall(r"customStatement\('(CREATE INDEX[^']*)'\)", source)
assert len(statements) == 4
with tempfile.TemporaryDirectory() as folder:
    path = Path(folder) / 'agenda.sqlite'
    db = sqlite3.connect(path)
    db.execute('PRAGMA foreign_keys = ON')
    for statement in statements:
        db.execute(statement)
    db.execute("INSERT INTO activities VALUES ('a','Reunión','work','2028-02-29',540,'Nota',1,1)")
    db.execute("INSERT INTO task_templates VALUES ('t','a','Preparar',0,1)")
    db.commit()
    db.close()
    db = sqlite3.connect(path)
    db.execute('PRAGMA foreign_keys = ON')
    assert db.execute('SELECT notes FROM activities').fetchone() == ('Nota',)
    assert db.execute('SELECT is_done FROM task_templates').fetchone() == (1,)
    try:
        with db:
            db.execute("UPDATE activities SET title = 'Cambio' WHERE id = 'a'")
            db.execute("INSERT INTO task_templates VALUES ('t','a','Colisión',1,0)")
    except sqlite3.IntegrityError:
        pass
    else:
        raise AssertionError('Se esperaba violación de clave primaria')
    assert db.execute('SELECT title FROM activities').fetchone() == ('Reunión',)
    for column, value in [('title', ''), ('category', 'invalid'), ('minute_of_day', 1440)]:
        try:
            with db:
                db.execute(f'UPDATE activities SET {column} = ? WHERE id = ?', (value, 'a'))
        except sqlite3.IntegrityError:
            pass
        else:
            raise AssertionError(f'Validación ausente: {column}')
    with db:
        db.execute("DELETE FROM activities WHERE id = 'a'")
    assert db.execute('SELECT count(*) FROM task_templates').fetchone() == (0,)
    assert db.execute('PRAGMA foreign_key_check').fetchall() == []
    db.close()
print('OK: esquema real, persistencia SQLite, rollback, restricciones y eliminación en cascada.')
