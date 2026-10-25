if [ $# -lt 1 ]; then
    echo "No overlay specified, please specify an overlay from bootstrap/overlays"
    exit 1
else
    OVERLAY=$1
    echo "Configuring cluster ${OVERLAY}"
fi

oc apply -n openshift-gitops -k bootstrap/overlays/${OVERLAY}
oc apply -n openshift-gitops -f bootstrap/root-app.yaml
