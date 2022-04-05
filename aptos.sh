#!/bin/bash
echo -e ''
TAG=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d '"' -f 4)
source $HOME/.profile
echo -e ''
curl -s https://api.testnet.run/logo.sh | bash && sleep 4
echo -e ''

dependient () {
    sudo apt-get update
    sudo apt-get install jq -y
    sudo apt install curl -y
    wget -q -O /usr/bin/yamq https://github.com/mikefarah/yq/releases/download/$TAG/yq_linux_amd64
    chmod +x /usr/bin/yamq
    sleep 1
}

binaries () {
    git clone https://github.com/aptos-labs/aptos-core.git
    cd aptos-core
    sleep 1
    git checkout origin/devnet &>/dev/null
    yes | ./scripts/dev_setup.sh && sleep 3
    source ~/.cargo/env
    cargo build -p aptos-node --release
    cargo build -p aptos-operational-tool --release
    mv ~/aptos-core/target/release/aptos-node /usr/bin
    mv ~/aptos-core/target/release/aptos-operational-tool /usr/bin
}

generate () {
    cd && mkdir aptos-node && cd aptos-node && mkdir data config
    wget -q -P $HOME/aptos-node/config https://raw.githubusercontent.com/Errorist79/aptos/main/public_full_node.yaml
    wget -q -P $HOME/aptos-node/config https://devnet.aptoslabs.com/genesis.blob
    wget -q -P $HOME/aptos-node/config https://devnet.aptoslabs.com/waypoint.txt
    sleep 1s
    aptos-operational-tool generate-key --encoding hex --key-type x25519 --key-file ~/aptos-node/config/private-key.txt
    aptos-operational-tool extract-peer-from-file --encoding hex --key-file ~/aptos-node/config/private-key.txt --output-file ~/aptos-node/config/peer-info.yaml &>/dev/null
    PRIV=$(cat ~/aptos-node/config/private-key.txt)
    PEER=$(sed -n 2p ~/aptos-node/config/peer-info.yaml | sed 's/.$//')
    source $HOME/.profile
    yamq e -i '.base.data_dir = "'$HOME/aptos-node/data'"' $HOME/aptos-node/config/public_full_node.yaml
    yamq e -i '.execution.genesis_file_location = "'$HOME/aptos-node/config'"' $HOME/aptos-node/config/public_full_node.yaml
    yamq e -i '.base.waypoint.from_file = "'$HOME/aptos-node/config'"' $HOME/aptos-node/config/public_full_node.yaml
    yamq e -i '.full_node_networks[] +=  { "identity": {"type": "from_config", "key": "'$PRIV'", "peer_id": "'$PEER'"} }' $HOME/aptos-node/config/public_full_node.yaml
}

service () {
sudo tee <<EOF >/dev/null /etc/systemd/system/aptosd.service
[Unit]
Description=Aptos daemon
After=network-online.target

[Service]
User=$USER
Type=simple
ExecStart=aptos-node -f $HOME/aptos-node/config/public_full_node.yaml
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
sleep 2
sed -i 's/#Storage=auto/Storage=persistent/g' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
sudo systemctl enable aptosd
sudo systemctl restart aptosd 
}

additional () {
    echo -e "\u001b[32m check the status:\u001b[0m \u001b[41;1mcurl 127.0.0.1:9101/metrics 2> /dev/null | grep "aptos_state_sync_version{type=\"synced\"}"\u001b[0m"
    echo -e "\u001b[32m Stop the node:\u001b[0m \u001b[41;1msystemctl stop aptosd\u001b[0m"
    echo -e "\u001b[32m start the node:\u001b[0m \u001b[41;1msystemctl start aptosd\u001b[0m"
    echo -e "\u001b[32m check the logs:\u001b[0m \u001b[41;1mjournalctl -u aptosd -f -n 100\u001b[0m"
}

update () {
    echo -e "Updating..." && sleep 2 
    systemctl stop aptosd && sleep 2 
    rm -rf $HOME/aptos-node/data && mkdir $HOME/aptos-node/data
    git checkout origin/devnet &>/dev/null
    wget -q -P $HOME/aptos-node/config https://devnet.aptoslabs.com/genesis.blob
    wget -q -P $HOME/aptos-node/config https://devnet.aptoslabs.com/waypoint.txt
    systemctl restart aptosd
    echo -e "\u001b[32mCheck the node status with this command:\u001b[0m \u001b[41;1curl 127.0.0.1:9101/metrics 2> /dev/null | grep "aptos_state_sync_version{type=\"synced\"}"\u001b[0m"
}



PS3="What do you want?: "
select opt in İnstall Update Additional Quit; 
do

  case $opt in
    İnstall)
    echo -e '\e[1;32mThe installation process begins...\e[0m'
    dependient
    binaries
    generate
    service
    additional
      break
      ;;
    Update)
    echo -e '\e[1;32mThe updating process begins...\e[0m'
    echo -e ''
    update
    sleep 1
      break
      ;;
    Additional)
    echo -e '\e[1;32mAdditional commands...\e[0m'
    echo -e ''
    additional
    sleep 1
      ;;
    Quit)
    echo -e '\e[1;32mexit...\e[0m' && sleep 1
      break
      ;;
    *) 
      echo "Invalid $REPLY"
      ;;
  esac
done
