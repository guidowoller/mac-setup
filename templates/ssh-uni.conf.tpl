# Generiert von setup.sh aus templates/ssh-uni.conf.tpl (Werte aus 1Password,
# Item "Mac-Setup Uni"). Nicht von Hand aendern - setup.sh ueberschreibt die Datei.
Host uni
    HostName {{ op://University/Mac-Setup Uni/uni/uni_ssh_host }}
    User {{ op://University/Mac-Setup Uni/uni/uni_ssh_user }}
