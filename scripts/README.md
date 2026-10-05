# Proteção do core

O instalador de skills tem duas versões equivalentes: `install-corporate-skills.ps1` para PowerShell no Windows e `install-corporate-skills.sh` para Bash no Linux e macOS. Veja [o catálogo de skills](../corporate-presets/skills/README.md) para os comandos.

No Linux/macOS, `protect-spec-kit.sh` salva os modos originais em `.guard/` e retira escrita de arquivos e diretórios do core. O desbloqueio restaura esses modos:

```bash
bash scripts/protect-spec-kit.sh lock
bash scripts/protect-spec-kit.sh status
bash scripts/protect-spec-kit.sh unlock
```

Não remova `.guard/spec-kit-modes.bin` enquanto o core estiver bloqueado; ela é necessária para restaurar as permissões. Em sistemas Unix, o proprietário pode alterar permissões novamente; para isolamento mais forte em CI, use um usuário distinto ou montagem somente leitura. O script recusa Git Bash no Windows.

No Windows, use a ACL descrita abaixo:

No Windows, execute `powershell -File scripts/protect-spec-kit.ps1 -Action Status` para consultar a ACL do diretório `spec-kit/`.

Para bloquear escrita, criação e exclusão pelo usuário atual:

```powershell
powershell -File scripts/protect-spec-kit.ps1 -Action Lock
```

Para uma atualização deliberada do core, desbloqueie, atualize e bloqueie novamente:

```powershell
powershell -File scripts/protect-spec-kit.ps1 -Action Unlock
# Atualize o core intencionalmente.
powershell -File scripts/protect-spec-kit.ps1 -Action Lock
```

A ACL impede alterações comuns feitas por processos do mesmo usuário. Um administrador ou proprietário com permissão de alterar ACLs ainda pode removê-la. Esta proteção não substitui revisão de mudanças nem controle de acesso de um repositório remoto.
