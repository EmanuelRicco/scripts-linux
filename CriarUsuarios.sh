#!/bin/bash

# Configurações
ARQUIVO_USUARIOS="usuarios.txt"
ARQUIVO_SENHAS="usuarios_senhas.txt"

# Função para gerar senha segura (letras maiúsculas, minúsculas e números)
gerar_senha() {
  < /dev/urandom tr -dc 'a-zA-Z0-9' | head -c 12
  echo
}

# Função para exibir mensagens com cores
info()  { echo -e "\e[36m[INFO]\e[0m $*"; }
aviso() { echo -e "\e[33m[AVISO]\e[0m $*"; }
erro()  { echo -e "\e[31m[ERRO]\e[0m $*"; exit 1; }
sucesso() { echo -e "\e[32m[SUCESSO]\e[0m $*"; }

# Verifica se está rodando como root
verificar_root() {
  if [[ $EUID -ne 0 ]]; then
    erro "Este script deve ser executado como root (ou com sudo)."
  fi
}

# Verifica se o arquivo de usuários existe e não está vazio
verificar_arquivo_usuarios() {
  if [[ ! -f "$ARQUIVO_USUARIOS" ]]; then
    erro "Arquivo '$ARQUIVO_USUARIOS' não encontrado."
  fi

  if [[ ! -s "$ARQUIVO_USUARIOS" ]]; then
    erro "Arquivo '$ARQUIVO_USUARIOS' está vazio."
  fi
}

# Verifica dependências
verificar_dependencias() {
  local comandos=("tr" "chpasswd" "id" "useradd" "head")
  for cmd in "${comandos[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      erro "Comando necessário ausente: $cmd"
    fi
  done
}

# Limpa o arquivo de senhas antes de começar
limpar_arquivo_senhas() {
  > "$ARQUIVO_SENHAS"
  info "Arquivo '$ARQUIVO_SENHAS' foi limpo."
}

# Processa cada usuário
processar_usuarios() {
  local total=0
  local criados=0
  local redefinidos=0

  while IFS= read -r usuario || [[ -n "$usuario" ]]; do
    # Ignora linhas em branco ou comentários
    [[ -z "$usuario" || "$usuario" =~ ^[[:space:]]*# ]] && continue

    # Remove espaços extras
    usuario=$(echo "$usuario" | xargs)

    # Exibe separador visual
    echo -e "\n\e[36m=============================\e[0m"
    info "Processando usuário: $usuario"

    # Verifica se o usuário já existe
    if id "$usuario" &>/dev/null; then
      aviso "Usuário '$usuario' já existe. Redefinindo senha."
      ((redefinidos++))
    else
      # Cria o usuário com shell nologin
      if useradd -s /sbin/nologin "$usuario" 2>/dev/null; then
        sucesso "Usuário '$usuario' criado com sucesso."
        ((criados++))
      else
        erro "Falha ao criar o usuário '$usuario'."
        continue
      fi
    fi

    # Gera e define a nova senha
    local senha=$(gerar_senha)
    if echo "$usuario:$senha" | chpasswd; then
      sucesso "Senha definida para o usuário '$usuario'."
      echo "$usuario $senha" >> "$ARQUIVO_SENHAS"
    else
      erro "Falha ao definir senha para o usuário '$usuario'."
    fi

    ((total++))
  done < "$ARQUIVO_USUARIOS"

  # Resumo final
  echo -e "\n\e[36m=============================\e[0m"
  info "PROCESSO CONCLUÍDO:"
  printf "%-30s %d\n" "[INFO] Usuários processados:" "$total"
  printf "%-30s %d\n" "[INFO] Usuários criados:" "$criados"
  printf "%-30s %d\n" "[INFO] Senhas redefinidas:" "$redefinidos"
  printf "%-30s %s\n" "[INFO] Credenciais salvas em:" "$ARQUIVO_SENHAS"
}

# Função principal
main() {
  verificar_root
  verificar_arquivo_usuarios
  verificar_dependencias
  limpar_arquivo_senhas
  processar_usuarios
}

# Executa o script
main "$@"