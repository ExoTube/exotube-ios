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


def run(request_json):
    try:
        request = json.loads(request_json)
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
        return json.dumps({'ok': False, 'error': friendly(error), 'detail': traceback.format_exc()[-3000:]})


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
