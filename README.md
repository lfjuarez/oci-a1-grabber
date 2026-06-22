# OCI A1 Instance Grabber

Workflow que reintenta crear una instancia Always Free **VM.Standard.A1.Flex (2 OCPU / 12 GB)**
en Oracle Cloud (São Paulo) cada 10 minutos, hasta que haya capacidad disponible.

## Seguridad / costos
- Crea **una sola** instancia (candado anti-duplicado en `grab.sh`).
- `concurrency` evita corridas en paralelo.
- Shape dentro del Always Free → **$0**.
- Usuario OCI `ci-launcher` con permisos **solo para crear instancias**.

## Cómo parar
Cuando la instancia esté creada, este repo se puede borrar o el workflow desactivar.
