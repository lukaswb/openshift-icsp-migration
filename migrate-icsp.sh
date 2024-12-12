#!/bin/bash

# This script migrates all ImageContentSourcePolicy (ICSP) objects in an OpenShift cluster.
# Ensure you are logged into your OpenShift cluster with sufficient permissions before running.

# Exit immediately if a command exits with a non-zero status
set -e

# Function to prompt for OpenShift login credentials and log in
function oc_login {
  read -p "Enter the OpenShift cluster name + domain (e.g., ocp.api.example.com): " cluster_name
  read -p "Enter your OpenShift username: " username
  read -s -p "Enter your OpenShift password: " password
  echo

  echo "Logging into OpenShift cluster..."
  oc login https://$cluster_name:6443 -u $username -p $password || {
    echo "Failed to log into the OpenShift cluster. Please check your credentials and try again."
    exit 1
  }
}

# Function to check if the user is logged in to OpenShift
function check_oc_login {
  if ! oc whoami > /dev/null 2>&1; then
    echo "You are not logged into an OpenShift cluster."
    oc_login
  fi
}

# Function to migrate ICSP objects
function migrate_icsp {
  echo "Fetching all ImageContentSourcePolicy (ICSP) objects..."

  # Create a directory to save ICSP definitions
  local backup_dir="icsp_backup_$(date +%Y%m%d%H%M%S)"
  mkdir -p "$backup_dir"
  echo "Created backup directory: $backup_dir"

  # List all ICSP objects
  icsp_list=$(oc get icsp -o jsonpath='{.items[*].metadata.name}')

  if [ -z "$icsp_list" ]; then
    echo "No ICSP objects found in the cluster. Exiting."
    exit 0
  fi

  echo "Found the following ICSP objects:"
  echo "$icsp_list"

  # Loop through each ICSP object, back it up, migrate it, and reapply it
  for icsp in $icsp_list; do
    echo "Processing ICSP: $icsp"

    # Save ICSP definition to backup directory
    echo "Backing up ICSP: $icsp"
    oc get icsp "$icsp" -o yaml > "$backup_dir/$icsp.yaml" || {
      echo "Failed to backup ICSP: $icsp. Exiting."
      exit 1
    }

    # Migrate the ICSP using oc (ensure version of oc is >4.12)
    echo "Migrating ICSP: $icsp"
    oc adm migrate icsp --icsp-name="$icsp" || {
      echo "Failed to migrate ICSP: $icsp. Exiting."
      exit 1
    }

    # //TODO: Apply ImageTagMirrorSet (itms) and ImageDigestMirrorSet (idms)
    echo "Apply ITMS/IDMS"
  done

  echo "All ICSP objects have been backed up, migrated, and reapplied successfully."
  echo "Backup files are located in: $backup_dir"
}

# Main script execution
check_oc_login
migrate_icsp
