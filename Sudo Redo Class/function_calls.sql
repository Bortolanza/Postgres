/*FUNCTION CALLS*/
SELECT redo.tag
     , redo.content
  FROM cria_trunca_e_popula_tabela('local_arquivo_log', 'local_arquivo_json') AS cria_trunca_e_popula_tabela(tabela)
  JOIN LATERAL redo(cria_trunca_e_popula_tabela.tabela) ON TRUE;
  