<!-- revisado à mão em 2026-09-15 (PT-BR). scripts/translate_md.py só sobrescreve este arquivo se ../en/04-scope.md mudar ou com --force. -->
# DELIMITAÇÃO

O trabalho restringe-se ao *driver* de grade única do WW3 (`ww3_shel`) na configuração operada pelo LabECO: sua grade, seu arquivo de *switches*, sua forçante e sua lista de saídas. Essa configuração e a revisão exata do código-fonte são congeladas e documentadas no início do projeto, de modo que todas as medidas se refiram ao mesmo caso.

Quatro etapas estão no escopo, executadas em ordem e cada uma validada por comparação com a execução de referência:

1. **Opções de compilação.** Compilador, *flags* de otimização, arquivo de *switches* (em particular memória compartilhada, MPI ou híbrido, e a saída NetCDF-4) e a distribuição de processos MPI e *threads* OpenMP. Não altera o código-fonte; espera-se reprodução bit a bit da referência ou, com reordenação de operações em ponto flutuante, diferenças da ordem do arredondamento.
2. **Configuração da execução.** Decomposição do domínio, passos de tempo permitidos pela condição CFL, frequência e campos de saída, estratégia de *restart* e interpolação da forçante. Altera apenas *namelists*.
3. **Refatoração dirigida em Fortran moderno.** Reescrita das rotinas que o perfil identificar como dominantes, tipicamente a integração dos termos de fonte (`W3SRCE`) e a propagação espacial, com construções padrão Fortran 2008/2018 (`do concurrent`, interfaces explícitas, vetores contíguos), sem alterar o algoritmo numérico e dentro de uma tolerância definida por campo de saída.
4. **Estudo de viabilidade em GPU (NVIDIA H100).** Um estudo, não um *port*: quais *kernels* podem executar no dispositivo, que dados precisariam residir nele e qual ganho é plausível, com base nos *ports* publicados do WW3 e do WAM e em um protótipo de um único *kernel* sobre a camada de portabilidade Kokkos [@trott2022]. O resultado é uma recomendação com medidas, não um *build* operacional.

A etapa 4 é deliberadamente a menor: o WAVEWATCH IV (WW4), reescrita do modelo com arquitetura voltada a GPU desde a origem, tem primeiro lançamento previsto para janeiro de 2027, e um *port* completo do WW3 concorreria com esse trabalho. Ficam fora do escopo o *driver* multigrade (`ww3_multi`), acoplamento com outros modelos, assimilação de dados, grades não estruturadas (PDLIB), salvo se a grade operacional as exigir, alterações nas parametrizações físicas e qualquer contribuição ao WW4 ou dependência dele.
