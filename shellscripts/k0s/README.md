# Kubernetes (k0s) + Cilium Firewall Configuration Guide

This guide explains how to configure `firewalld` to allow necessary network traffic for a Kubernetes cluster using **k0s** and **Cilium** CNI, including the **Hubble Relay** component.

---

## Background

By default, `firewalld` can block essential networking traffic required by Kubernetes components and Cilium’s overlay network. This often causes issues such as:

- Pods failing to become ready (e.g., `hubble-relay` pods)
- DNS resolution failures inside the cluster
- Network connectivity problems between pods

---

## Why does this happen?

- Kubernetes uses certain ports and protocols for API server, DNS, and NodePort services.
- Cilium relies on VXLAN or other overlay protocols requiring specific UDP ports.
- Blocking these ports causes communication failures.

---

## Ports and Protocols to Allow

| Port/Protocol        | Description                          |
|---------------------|------------------------------------|
| **UDP 53**          | DNS queries (CoreDNS)               |
| **TCP 53**          | DNS over TCP fallback               |
| **TCP 6443**        | Kubernetes API Server               |
| **UDP 4789**        | VXLAN overlay networking (Cilium)  |
| **TCP/UDP 30000-32767** | NodePort services                 |

---

## How to Configure `firewalld`

Run the following commands to allow necessary ports:

```bash
sudo firewall-cmd --permanent --add-port=53/udp
sudo firewall-cmd --permanent --add-port=53/tcp
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=4789/udp
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo firewall-cmd --permanent --add-port=30000-32767/udp
sudo firewall-cmd --reload
