#!/bin/bash

# Define cores
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m" # No Color

# Função para imprimir um banner que permanece na tela
function print_banner {
  clear
  echo -e "${GREEN}"
  echo "============================================="
  echo "         Whaticket Optimizer        "
  echo "============================================="
  echo -e "${NC}"
}

# Função para criar o sufixo incrementado
function get_incremented_folder_name {
  base_name="$1-old"
  increment=1
  new_folder_name="$base_name"

  while [ -d "$new_folder_name" ]; do
    new_folder_name="${base_name}-${increment}"
    increment=$((increment + 1))
  done

  echo "$new_folder_name"
}

# Exibe o banner
print_banner

# Parando todas as tarefas do PM2
echo -e "${GREEN}Parando todas as tarefas do PM2...${NC}"
sudo su deploy -c "pm2 stop all"
sudo su deploy -c "exit"

# Exibe o banner novamente
print_banner

# Definindo o caminho padrão de deploy
deploy_path="/home/deploy"

# Verifica se o diretório existe
if [ ! -d "$deploy_path" ]; then
  echo -e "${RED}Caminho $deploy_path não existe. Operação cancelada.${NC}"
  exit 1
fi

# Tenta acessar o diretório
cd "$deploy_path" || { 
  echo -e "${RED}Falha ao acessar o caminho $deploy_path. Operação cancelada.${NC}"
  exit 1
}

# Continua com o restante do script
echo -e "${GREEN}Diretório de deploy definido para $deploy_path.${NC}"

# Exibe o banner novamente
print_banner

# Solicitando o nome da pasta a ser renomeada
echo -e "${GREEN}Digite o nome da pasta que deseja renomear:${NC}"
read old_folder_name

if [ ! -d "$old_folder_name" ]; then
  echo -e "${RED}A pasta $old_folder_name não existe. Operação cancelada.${NC}"
  exit 1
fi

# Exibe o banner novamente
print_banner

# Determinando o nome da nova pasta (incrementando se necessário)
new_old_folder_name=$(get_incremented_folder_name "$old_folder_name")
mv "$old_folder_name" "$new_old_folder_name"

# Solicitando o novo nome para a pasta
echo -e "${GREEN}Digite o novo nome para a pasta:${NC}"
read new_folder_name

# Verifica se o novo nome da pasta já existe para evitar conflitos
if [ -d "$new_folder_name" ]; then
  echo -e "${RED}A pasta $new_folder_name já existe. Operação cancelada.${NC}"
  exit 1
fi

# Exibe o banner novamente
print_banner

# Clonando o repositório público do GitHub
echo -e "${GREEN}Digite a URL do repositório público do GitHub (ex: https://github.com/usuario/repo.git):${NC}"
read repo_url

# Verifica se a URL está no formato correto
if [[ ! "$repo_url" =~ ^https://github\.com/.+/.+\.git$ ]]; then
    echo -e "${RED}URL inválida. Por favor, insira uma URL válida do GitHub (ex: https://github.com/usuario/repo.git).${NC}"
    exit 1
fi

# Clonando o repositório diretamente para o nome escolhido
git clone "$repo_url" "$new_folder_name"

# Verifica se o clone foi bem-sucedido
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Repositório clonado com sucesso em $deploy_path/$new_folder_name.${NC}"
else
  echo -e "${RED}Falha ao clonar o repositório.${NC}"
  exit 1
fi

# Exibe o banner novamente
print_banner

# Copiando arquivos .env e server.js
echo -e "${GREEN}Copiando arquivos .env e server.js...${NC}"
cp "$new_old_folder_name/backend/.env" "$new_folder_name/backend/.env"
cp "$new_old_folder_name/frontend/.env" "$new_folder_name/frontend/.env"
cp "$new_old_folder_name/frontend/server.js" "$new_folder_name/frontend/server.js"

# Exibe o banner novamente
print_banner

# Executando comandos no backend
echo -e "${GREEN}Rodando comandos no backend...${NC}"
cd "$deploy_path/$new_folder_name/backend" || { echo -e "${RED}Falha ao acessar o diretório do backend. Operação cancelada.${NC}"; exit 1; }
npm install
npm run build
npx sequelize db:migrate

# Exibe o banner novamente
print_banner

# Executando comandos no frontend
echo -e "${GREEN}Rodando comandos no frontend...${NC}"
cd "$deploy_path/$new_folder_name/frontend" || { echo -e "${RED}Falha ao acessar o diretório do frontend. Operação cancelada.${NC}"; exit 1; }
npm install
npm run build

# Exibe o banner novamente
print_banner

# Editando package.json no frontend
echo -e "${GREEN}Abrindo o package.json no frontend para editar...${NC}"
nano "$deploy_path/$new_folder_name/frontend/package.json"

# Exibe o banner novamente
print_banner

# Editando index.html no frontend/public
echo -e "${GREEN}Abrindo o index.html no frontend/public para editar...${NC}"
nano "$deploy_path/$new_folder_name/frontend/public/index.html"

# Exibe o banner novamente
print_banner

# Rodando novamente npm install e npm run build no frontend
echo -e "${GREEN}Rodando npm install e npm run build novamente no frontend...${NC}"
npm install
npm run build

# Exibe o banner novamente
print_banner

# Reiniciando o PM2
echo -e "${GREEN}Reiniciando o PM2...${NC}"
sudo su deploy -c "pm2 restart all"

# Exibe o banner novamente
print_banner

# Instrução para mover a pasta public
echo -e "${RED}Mova a pasta 'public' para o novo diretório, se necessário.${NC}"

# Exibe o banner novamente
print_banner

echo -e "${GREEN}Script finalizado. Se aconteceu algum erro nos chame no suporte!${NC}"
echo -e "${GREEN}
npm install (No backend)
npm run build (No backend)
npx sequelize db:migrate (No backend)

npm install (No frontend)
npm run build (No frontend)

sudo su deploy
pm2 restart all
${NC}"

# Informações de contato

echo -e "${GREEN}Site: loja.yranolv.dev.br${NC}"

