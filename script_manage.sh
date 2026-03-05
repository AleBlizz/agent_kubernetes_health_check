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
    product-catalog-api)
        case "$2" in
            logs)
                echo "Logs for product-catalog-api:"
                kubectl logs -l app=product-catalog-api --tail=100 -f
                ;;
            restart)
                echo "Restarting product-catalog-api..."
                kubectl rollout restart deployment/product-catalog-api
                kubectl rollout status deployment/product-catalog-api
                ;;
            status)
                echo "Status for product-catalog-api:"
                kubectl get deployment product-catalog-api
                echo ""
                kubectl get pods -l app=product-catalog-api
                ;;
            *)
                echo "Usage: $0 product-catalog-api {logs|restart|status}"
                exit 1
                ;;
        esac
        ;;
    order-analytics-worker)
        case "$2" in
            logs)
                echo "Logs for order-analytics-worker:"
                kubectl logs -l app=order-analytics-worker --tail=100 -f
                ;;
            restart)
                echo "Restarting order-analytics-worker..."
                kubectl rollout restart deployment/order-analytics-worker
                kubectl rollout status deployment/order-analytics-worker
                ;;
            status)
                echo "Status for order-analytics-worker:"
                kubectl get deployment order-analytics-worker
                echo ""
                kubectl get pods -l app=order-analytics-worker
                ;;
            *)
                echo "Usage: $0 order-analytics-worker {logs|restart|status}"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Usage: $0 {start|delete|status|restart|product-catalog-api|order-analytics-worker}"
        echo "       $0 product-catalog-api {logs|restart|status}"
        echo "       $0 order-analytics-worker {logs|restart|status}"
        exit 1
        ;;
esac