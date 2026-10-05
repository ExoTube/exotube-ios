"""Puente entre la app de iPhone (Swift) y yt-dlp.

Swift no puede llamar a yt-dlp directamente: le manda a [run] un pedido en JSON y recibe la
respuesta en JSON. Así el lado de Swift no necesita saber nada de Python.

Pedidos:
  {"action": "version"}
  {"action": "info", "url": "..."}                         -> título, autor, duración, miniatura
  {"action": "download", "url": "...", "folder": "...",
   "progress_file": "..."}                                  -> ruta del archivo descargado

En iPhone no hay ffmpeg para juntar imagen y sonido, así que siempre se elige un formato que ya
los traiga juntos (TikTok, X y Facebook lo dan así; de Instagram, el mejor que lo tenga).
"""
import json
import os
import sys
import traceback

# Python en iPhone no ve los certificados del sistema: se usan los de certifi.
try:
    import certifi
    os.environ.setdefault('SSL_CERT_FILE', certifi.where())
except ImportError:  # pragma: no cover - sin certifi fallarían las conexiones seguras
    pass

FORMAT = 'b[ext=mp4][vcodec!=none][acodec!=none]/b[vcodec!=none][acodec!=none]/b'

# Registro detallado de yt-dlp (lo indica Swift con "log_file"): sirve para saber por qué falla
# una red sin tener el teléfono en la mano. Solo se guarda el último pedido.
_log_path = None


class _FileLogger:
    def _write(self, level, message):
        if _log_path:
            with open(_log_path, 'a', encoding='utf-8') as f:
                f.write('%s %s\n' % (level, message))

    def debug(self, message):
        self._write('DEBUG', message)

    def info(self, message):
        self._write('INFO', message)

    def warning(self, message):
        self._write('WARNING', message)

    def error(self, message):
        self._write('ERROR', message)


def run(request_json):
    try:
        request = json.loads(request_json)
        global _log_path
        _log_path = request.get('log_file')
        if _log_path:
            open(_log_path, 'w').close()
        action = request.get('action')
        if action == 'version':
            import yt_dlp.version
            result = {'yt_dlp': yt_dlp.version.__version__, 'python': sys.version.split()[0]}
        elif action == 'info':
            result = info(request['url'])
        elif action == 'download':
            result = download(request['url'], request['folder'], request.get('progress_file'))
        else:
            raise ValueError('pedido desconocido: %r' % action)
        return json.dumps({'ok': True, 'result': result})
    except Exception as error:  # se devuelve como texto: Swift lo enseña al usuario
        detail = traceback.format_exc()
        if _log_path:
            _FileLogger().error(detail)
        return json.dumps({'ok': False, 'error': friendly(error), 'detail': detail[-3000:]})


def _ydl(extra=None):
    import yt_dlp
    options = {
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
        'format': FORMAT,
        'socket_timeout': 20,
        'retries': 3,
        'cachedir': False,
    }
    if _log_path:
        options.update({'verbose': True, 'logger': _FileLogger()})
    options.update(extra or {})
    return yt_dlp.YoutubeDL(options)


def _summary(i):
    return {
        'id': i.get('id'),
        'title': i.get('title') or i.get('description') or 'Video',
        'uploader': i.get('uploader') or i.get('channel') or i.get('creator') or '',
        'duration': i.get('duration'),
        'thumbnail': i.get('thumbnail'),
        'site': i.get('extractor_key') or '',
        'filesize': i.get('filesize') or i.get('filesize_approx'),
    }


def info(url):
    with _ydl() as ydl:
        return _summary(ydl.extract_info(url, download=False))


def download(url, folder, progress_file=None):
    def hook(d):
        if progress_file and d.get('status') == 'downloading':
            total = d.get('total_bytes') or d.get('total_bytes_estimate') or 0
            with open(progress_file, 'w') as f:
                f.write('%d %d' % (d.get('downloaded_bytes') or 0, total))

    options = {'outtmpl': os.path.join(folder, '%(id)s.%(ext)s'), 'progress_hooks': [hook]}
    with _ydl(options) as ydl:
        i = ydl.extract_info(url, download=True)
        result = _summary(i)
        result['path'] = ydl.prepare_filename(i)
        return result


def friendly(error):
    """El error de yt-dlp, en palabras que entienda cualquiera."""
    text = str(error)
    lower = text.lower()
    if 'login' in lower or 'cookies' in lower or 'private' in lower:
        return 'Esta publicación es privada o pide iniciar sesión.'
    if 'unsupported url' in lower:
        return 'Ese enlace no es de un video que ExoTube sepa descargar.'
    if 'urlopen error' in lower or 'timed out' in lower or 'connection' in lower:
        return 'Sin conexión. Revisa tu internet e inténtalo otra vez.'
    return text.replace('ERROR: ', '')[:300]
