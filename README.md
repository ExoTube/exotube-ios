# ExoTube para iPhone

La versión de iPhone de [ExoTube](https://exotube.github.io): música y videos sin anuncios, gratis y de código abierto (GPLv3).

> En construcción. La app de Android está en [ExoTube/android](https://github.com/ExoTube/android).

## Cómo se instala

Apple no deja publicar esta app en la App Store ni instalarla desde una página web, así que se instala a mano con **AltStore** o **Sideloadly**, usando tu propia cuenta de Apple (gratis). Con una cuenta gratis la app dura 7 días y luego hay que renovarla (AltStore lo hace solo si tu computadora está encendida en la misma Wi-Fi).

## Cómo se compila

No hace falta una Mac: cada cambio se compila en una Mac de GitHub Actions (`.github/workflows/compilar.yml`), que:

1. genera el proyecto de Xcode desde `project.yml` con [XcodeGen](https://github.com/yonaskolb/XcodeGen);
2. pasa las pruebas en un iPhone simulado;
3. saca capturas de cada pantalla;
4. arma `ExoTube.ipa` sin firmar (la firma cada persona al instalarla).
