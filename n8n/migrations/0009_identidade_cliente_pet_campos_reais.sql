-- 0009 — Substitui o schema chutado de identidade_cliente_pet (Story 1, 4 colunas de
-- negócio) por campos reais, com base em _bmad-output/reference/clientes.csv (export
-- real do SimplesVet do Nouvet) e no print de tela do cadastro (achado de
-- correct-course). Escopo dos campos novos = "dados do responsável, animal e
-- endereço" (Thiago) -- deliberadamente NÃO importa colunas comerciais/analíticas do
-- SimplesVet (NPS, ranking ABC, valores pagos, ticket médio, datas de compra) porque
-- isso é papel do funil no RD CRM (AD-6), não da identidade operacional rápida.
--
-- ALTER TABLE sobre a tabela criada na 0003 (nunca recria).

ALTER TABLE identidade_cliente_pet
	-- Responsável: campos que o cadastro do SimplesVet já pede hoje e o cliente
	-- normalmente informa uma vez só.
	ADD COLUMN cpf VARCHAR(14),
	ADD COLUMN rg VARCHAR(20),
	ADD COLUMN data_nascimento_cliente DATE,
	ADD COLUMN email VARCHAR(200),

	-- Endereço do cliente (pode não existir -- "Não possui endereço cadastrado" é
	-- estado real e comum no cadastro hoje, por isso tudo nullable).
	ADD COLUMN endereco VARCHAR(300),
	ADD COLUMN bairro VARCHAR(100),
	ADD COLUMN cidade VARCHAR(100),
	ADD COLUMN uf CHAR(2),
	ADD COLUMN cep VARCHAR(9),

	-- Animal: campos que o cadastro do SimplesVet já pede hoje.
	ADD COLUMN pelagem_pet VARCHAR(100),
	ADD COLUMN esterilizado_pet BOOLEAN,
	ADD COLUMN pedigree_pet BOOLEAN,
	ADD COLUMN microchip_pet VARCHAR(50),
	ADD COLUMN vivo_pet BOOLEAN NOT NULL DEFAULT TRUE,
	ADD COLUMN data_nascimento_pet DATE,

	-- Referência ao código do animal no SimplesVet -- permite reconciliar o import
	-- real (última ação antes do go-live) sem depender só de match fuzzy por
	-- (telefone, nome_pet); nunca usado como chave de identidade em si.
	ADD COLUMN simplesvet_codigo_animal INTEGER;
