# Antigravity Bootstrap v3.1 — Documentação Ultra-Detalhada

> **Localização Recomendada:** `.antigravity/bootstrap.sh`  
> **Versão:** 3.1 SOTA (Location-Aware / Dynamic Path)  
> **Target:** Servidores remotos Linux (LXC/Proxmox, VPS) — headless, SSH-safe  
> **Arquitetura:** One-User-Per-Project (Isolamento de $HOME)

---

## Índice

1. [Diferenciais da v3.1](#1-diferenciais-da-v31)
2. [Arquitetura de Conhecimento Dual](#2-arquitetura-de-conhecimento-dual)
3. [Merge Inteligente de MCP](#3-merge-inteligente-de-mcp)
4. [Git Hooks Dinâmicos](#4-git-hooks-dinâmicos)
5. [Tabela de Model Routing](#5-tabela-de-model-routing)
6. [Configurações da IDE (settings.json)](#6-configurações-da-ide-settingsjson)

---

## 1. Diferenciais da v3.1

Esta versão foi otimizada para o modelo **um usuário Linux por projeto**, garantindo isolamento total e performance máxima:

- **Consciência de Path:** O script detecta automaticamente onde está instalado em relação à raiz do Git. Se você colocar em `.antigravity/`, os git hooks saberão exatamente onde buscá-lo para reconstruir o contexto.
- **Merge não-destrutivo:** Ao configurar o MCP, o script não sobrescreve seu arquivo global. Ele lê o `~/.gemini/antigravity/mcp_config.json` existente e apenas injeta ou atualiza as chaves do projeto atual.
- **Symlink Inteligente:** O arquivo de regras (`coding-standards.md`) vive dentro do seu projeto em `.antigravity/knowledge/` (para ser versionado no Git), mas é "linkado" para a pasta global da IDE. Você edita no projeto e a IDE aprende instantaneamente.

---

## 2. Arquitetura de Conhecimento Dual

| Arquivo | Localização Real | Visibilidade IDE | Papel |
|---------|------------------|------------------|-------|
| **stack-context.md** | `~/.gemini/antigravity/knowledge/` | ✅ Global | Fingerprint técnico (Node/Python, pastas, deps). Efêmero. |
| **coding-standards.md** | `$PROJECT/.antigravity/knowledge/` | ✅ Global (via Symlink) | Regras de ouro, ética de código e model routing. Persistente. |

---

## 3. Merge Inteligente de MCP

Diferente das versões anteriores, a v3.1 faz o merge via `jq`:
- Mantém seus servidores MCP já configurados (ex: `supabase`, `cloud-run`).
- Garante que `local-filesystem` aponte exatamente para a pasta do projeto atual (`$PWD`).
- Garante que `local-git` esteja rastreando o repositório correto.

---

## 4. Git Hooks Dinâmicos

Os hooks injetados no `.git/hooks/antigravity-sync` são autoconscientes:
- **post-commit:** Sinaliza uma "evolução" de conhecimento sempre que você faz um commit.
- **post-merge/checkout:** Se você baixar mudanças que alterem `package.json`, `requirements.txt` ou `pyproject.toml`, o hook **re-executa o bootstrap** automaticamente para atualizar o contexto do agente.

---

## 5. Tabela de Model Routing

O agente usará esta tabela (definida no seu `coding-standards.md`) para decidir qual modelo GPT/Claude/Gemini usar:

| Tarefa | Modelo Recomendado |
|--------|-------------------|
| Edição, comandos, código simples | `gemini-3-flash` |
| Debugging e lógica intermediária | `gemini-3.1-pro-low` |
| Arquitetura e problemas complexos | `gemini-3.1-pro-high` |
| Auditoria e síntese de conhecimento | `claude-sonnet-4.6-thinking` |
| Decisões críticas e segurança | `claude-opus-4.6-thinking` |

---

---

## 7. Como Iniciar (Quick Start)

Para uma instalação limpa e organizada, execute:

```bash
mkdir -p .antigravity
curl -sSL https://raw.githubusercontent.com/brunoguirado/scripts/main/google/antigravity/bootstrap.sh > .antigravity/bootstrap.sh
bash .antigravity/bootstrap.sh
```

Isso manterá a raiz do seu projeto limpa enquanto fornece todo o poder do Antigravity.
