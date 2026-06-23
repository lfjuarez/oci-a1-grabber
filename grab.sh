#!/bin/bash
# Un intento de crear la instancia A1.Flex. El cron de GitHub provee el loop.
# SEGURO: si ya existe una instancia A1 viva, NO crea otra (cero riesgo de cargo).
set -uo pipefail
export SUPPRESS_LABEL_WARNING=True

# ---- Parámetros (Always Free: 2 OCPU / 12 GB) ----
COMPARTMENT="ocid1.tenancy.oc1..aaaaaaaalzgohnwaapcncrxxkjnbfachveqwgnqg74wb3stn7ms5ipue3a5a"
AD="XrNv:SA-SAOPAULO-1-AD-1"
SUBNET="ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaaj2bzrsaq6gnmu3gwehtc5ulevwbbpolz5foftkmhlwxmgfo4xlxq"
IMAGE="ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaemf52b7af7ncncxz6pdc6hrlkdmylvwejfzpwnpbuhlfxwhrno6a"
SHAPE="VM.Standard.A1.Flex"
OCPUS=2
MEM_GB=12
DISPLAY_NAME="presupuestar-prod"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ---- Candado anti-duplicado ----
EXISTING=$(oci compute instance list -c "$COMPARTMENT" --output json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    alive = [i for i in d.get('data', [])
             if i.get('shape')=='VM.Standard.A1.Flex'
             and i.get('lifecycle-state') not in ('TERMINATED','TERMINATING')]
    print(len(alive))
except: print(0)
")

if [ "${EXISTING:-0}" -gt 0 ]; then
  echo "[$(ts)] Ya existe una instancia A1 viva. No creo otra. Salgo OK."
  exit 0
fi

echo "[$(ts)] Intentando crear ${SHAPE} ${OCPUS}OCPU/${MEM_GB}GB..."

OUT=$(oci compute instance launch \
  --availability-domain "$AD" \
  --compartment-id "$COMPARTMENT" \
  --shape "$SHAPE" \
  --shape-config "{\"ocpus\":$OCPUS,\"memoryInGBs\":$MEM_GB}" \
  --image-id "$IMAGE" \
  --subnet-id "$SUBNET" \
  --assign-public-ip true \
  --display-name "$DISPLAY_NAME" \
  --ssh-authorized-keys-file ./ssh_key.pub \
  2>&1)

if echo "$OUT" | grep -q '"lifecycle-state"'; then
  echo "[$(ts)] ✅✅✅ INSTANCIA CREADA ✅✅✅"
  INSTANCE_INFO=$(echo "$OUT" | grep -v Warning | python3 -c "
import sys, json
d = json.load(sys.stdin)['data']
print('OCID:', d['id'])
print('Estado:', d['lifecycle-state'])
")
  echo "$INSTANCE_INFO"
  # Notificación push via ntfy.sh
  curl -s -o /dev/null \
    -H "Title: ✅ Oracle VM creada!" \
    -H "Priority: urgent" \
    -H "Tags: white_check_mark,cloud" \
    -d "presupuestar-prod lista. Conseguí la IP con: oci compute instance list-vnics --instance-id <OCID>" \
    https://ntfy.sh/lfjuarez-oci-vm-prod || true
  exit 0
elif echo "$OUT" | grep -qiE "out of (host )?capacity|InternalError"; then
  echo "[$(ts)] Sin capacidad. Reintenta el próximo cron."
  exit 0
elif echo "$OUT" | grep -qiE "timed out|timeout|connection|RequestException|ServiceError"; then
  echo "[$(ts)] Error de red/transitorio. Reintenta el próximo cron."
  exit 0
else
  echo "[$(ts)] Error inesperado:"
  echo "$OUT" | grep -v Warning | head -20
  exit 1
fi
