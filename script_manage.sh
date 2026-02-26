#!/bin/bash

# Configuration
FILE_NAME="./deployment_cart_payment_service_simulation.yaml"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl could not be found. Please install it to use this script."
    exit 1
fi

case "$1" in
    start)
        echo "Starting deployments from $FILE_NAME..."
        kubectl apply -f "$FILE_NAME"
        ;;
    delete)
        echo "Deleting deployments defined in $FILE_NAME..."
        kubectl delete -f "$FILE_NAME"
        ;;
    status)
        echo "Current status of deployments:"
        kubectl get deployments --all-namespaces
        echo ""
        kubectl get pods --all-namespaces
        ;;
    restart)
        echo "♻️  Performing rolling restart of deployments..."
        # This gets the names of all deployments defined in your YAML and restarts them
        DEPLOYMENT_NAMES=$(grep "name:" "$FILE_NAME" | awk '{print $2}')
        for deploy in $DEPLOYMENT_NAMES; do
            echo "Restarting: $deploy"
            kubectl rollout restart -f "$FILE_NAME"
        
            echo "Waiting for rollout to complete..."
            kubectl rollout status -f "$FILE_NAME"
        done
        ;;
    *)
        echo "Usage: $0 {start|delete|status|restart}"
        exit 1
        ;;
esac