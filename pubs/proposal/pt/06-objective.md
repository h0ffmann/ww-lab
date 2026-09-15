<!-- revisado à mão em 2026-09-15 (PT-BR). scripts/translate_md.py só sobrescreve este arquivo se ../en/06-objective.md mudar ou com --force. -->
# OBJETIVO

O objetivo geral é reduzir, de forma medida e reprodutível, o tempo de execução do ciclo operacional do WAVEWATCH III mantido pelo LabECO/UFSC no âmbito do ReNOMO, sem alterar seus resultados científicos além das tolerâncias acordadas com o laboratório, e entregar uma recomendação escrita sobre até onde essa redução pode ser levada com o hardware disponível, incluindo uma GPU NVIDIA H100.

Os objetivos específicos são:

1. Congelar e documentar a configuração operacional (revisão do código, *switches*, *namelists*, grade, forçante, saídas, hardware) e construir um *benchmark* reprodutível da execução de referência, com métrica definida (tempo de execução por hora de previsão).
2. Produzir um perfil da execução de referência por rotina e por fase (termos de fonte, propagação, comunicação, entrada e saída), com um e com vários processos MPI.
3. Quantificar o ganho de cada etapa de otimização, cada uma com sua evidência de paridade em relação à referência, e entregar ao laboratório a melhor configuração como um *build* documentado.
4. Avaliar a viabilidade de execução em GPU em um H100 por meio de um estudo e de um protótipo de *kernel* único, reportando números medidos, as restrições de movimentação de dados e a posição desse resultado frente ao primeiro lançamento do WW4.
5. Publicar ferramentas, resultados e recomendação no repositório aberto, em forma que o laboratório possa reexecutar.
