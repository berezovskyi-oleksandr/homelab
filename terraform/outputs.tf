output "kubeconfig" {
  value = {
    for key, cluster in var.clusters :
    key => talos_cluster_kubeconfig.talos-kubeconfig[key].kubeconfig_raw
  }
  sensitive = true
}

output "talosconfig" {
  value = {
    for key, cluster in var.clusters :
    key => data.talos_client_configuration.talos-client-config[key].talos_config
  }
  sensitive = true
}
