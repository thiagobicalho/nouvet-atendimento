-- 0007 — Renomeia as tabelas/função que reaproveitavam o prefixo "secretaria_" do
-- template de referência (secretariav3-completo) sem decisão do Thiago (achado de
-- correct-course, sprint-change-proposal-2026-09-02.md). Tabelas n8n_* e
-- identidade_cliente_pet não mudam de nome (não faziam parte da queixa).
--
-- RENAME preserva GRANTs, índices e dependências automaticamente -- nenhum GRANT
-- precisa ser reconcedido.

ALTER TABLE secretaria_config RENAME TO atendimento_config;
ALTER TABLE secretaria_profissionais RENAME TO atendimento_profissionais;
ALTER FUNCTION secretaria_config_ler(TEXT, TEXT) RENAME TO atendimento_config_ler;
