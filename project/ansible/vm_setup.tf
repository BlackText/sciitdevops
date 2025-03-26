---
- name: Configure VMs for Docker, K3s, and Git
  hosts: all
  become: true
  tasks:
    # Firewall Management
    - name: Allow SSH (port 22)
      ufw:
        rule: allow
        name: OpenSSH
        state: enabled

    - name: Allow HTTP (port 80)
      ufw:
        rule: allow
        name: 'Apache'
        state: enabled

    - name: Allow HTTPS (port 443)
      ufw:
        rule: allow
        name: 'Apache Secure'
        state: enabled

    - name: Allow Kubernetes ports (6443, 10250, 10255, etc.)
      ufw:
        rule: allow
        port: "{{ item }}"
        proto: tcp
        state: enabled
      loop:
        - 6443
        - 10250
        - 10255
        - 2379
        - 2380

    # Install Docker and dependencies
    - name: Update apt package index
      apt:
        update_cache: yes

    - name: Install required packages for Docker and Kubernetes
      apt:
        name:
          - apt-transport-https
          - ca-certificates
          - curl
          - gnupg
          - lsb-release
        state: present

    - name: Add Docker GPG key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      apt_repository:
        repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        state: present

    - name: Install Docker
      apt:
        name: docker-ce
        state: present

    - name: Install K3s
      shell: |
        curl -sfL https://get.k3s.io | sh -

    - name: Install Git
      apt:
        name: git
        state: present

    # SSH Key Setup
    - name: Create .ssh directory for the user
      file:
        path: "/home/{{ ansible_user }}/.ssh"
        state: directory
        mode: '0700'
        owner: "{{ ansible_user }}"
        group: "{{ ansible_user }}"

    - name: Add SSH public key to the authorized_keys
      authorized_key:
        user: "{{ ansible_user }}"
        state: present
        key: "{{ lookup('file', '/path/to/public/key.pub') }}"  # Ensure this points to the correct SSH public key

