# Teste de rua · 0.16.0

O que só dá para medir andando de verdade, com o moto g54, a 0.16.0+25 instalada e o simulador de GPS **desligado** (debug > Posição). Anote os números nas tabelas abaixo, neste arquivo, e me passe. O que foi medido no simulado em 2026-11-09 está no fim, para comparar.

Antes de sair:

- Bateria carregada acima de 80% e fora do carregador por pelo menos 10 minutos antes de começar (logo depois de tirar do cabo a leitura engana).
- Wi-Fi e dados como você usa normalmente. Brilho automático.
- Feche os outros apps que usam GPS (mapas, corrida).
- Patrulha: botão "Patrulha" no mapa, duração de 2 h. Na primeira vez o Android pede notificações e localização "durante o uso".

## 1. Bateria: 30 minutos de Patrulha com a tela apagada

1. Anote a hora e a bateria (%) ao ligar a Patrulha.
2. Bloqueie a tela e ande 30 minutos sem abrir o app.
3. Anote a hora e a bateria ao desbloquear, antes de abrir o app.
4. Gasto por hora = (bateria inicial - final) × 60 / minutos. Meta: até 6% por hora.

| Data | Início (hora, %) | Fim (hora, %) | Minutos | %/h | Clima e temperatura | Observação |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

Se passar de 6%/h, o primeiro ajuste é `patrol.gps_interval_s` no `balance.json` (hoje 10 s).

## 2. Patrulha de 15 minutos com a tela bloqueada

Pode ser a mesma caminhada do item 1, nos primeiros 15 minutos.

| O que conferir | Como | Resultado |
| --- | --- | --- |
| A notificação atualiza com a tela bloqueada | Acenda a tela sem desbloquear e olhe "N Fagulhas · N Ecos marcados · N min" duas ou três vezes | |
| Fagulhas no fim de 15 min | Número da notificação | |
| Ecos marcados no fim de 15 min | Número da notificação | |
| A Patrulha continua depois de tirar o app dos recentes | Tire o app da lista de recentes e veja se a notificação segue | |
| Botão "Abrir" da notificação | Toque com a tela desbloqueada | |
| Botão "Encerrar" da notificação | Toque no fim | |
| Resumo no Chat | Abra o app depois de encerrar; Chat do mentor | |
| Incorporação | Fagulhas da notificação somam na Bolsa, sem duplicar | |
| Passos não contam em dobro | Perfil > Passos hoje antes e depois; com a Patrulha ligada eles não viram Fagulha de novo | |

## 3. Vibrações e avisos

| O que conferir | Resultado |
| --- | --- |
| Vibração curta quando um Eco comum é marcado (tela bloqueada, celular no bolso) | |
| Padrão diferente para raro (Brilhante, variante, Espírito) | |
| Notificação "Algo raro passou a N m, na R. X" com o nome da rua certo | |
| Tocar no aviso de raro abre o app no Eco (com o app fechado e com o app em segundo plano) | |
| Em carro ou ônibus: a pergunta "Sou passageiro / Estou dirigindo" aparece na notificação | |
| Modo bolso com a Patrulha ligada e o app aberto: cobrir o sensor apaga a tela e destapar volta | |

## 4. Passos (pode ser no dia a dia)

| O que conferir | Resultado |
| --- | --- |
| Passos do dia no Perfil batem com o contador do celular (Google Fit ou similar), com diferença pequena | |
| Fala do Familiar ao passar de 5 mil e de 10 mil | |
| Reiniciar o celular no meio do dia não dobra nem zera os passos convertidos | |

## Medido no simulado em 2026-11-09 (não é caminhada real)

- Patrulha simulada pelo debug, a 1,4 m/s: em 4 minutos, 22 Fagulhas, 17 materiais e 1 Eco marcado; a notificação atualizou com o app aberto e, com a tela bloqueada por 4 minutos, foi a "6 Fagulhas · 1 Eco marcado · 4 min", com uma vibração de 136 ms na marcação; o app incorporou o diário com a Patrulha ativa e o resumo saiu no Chat.
- A bateria não foi medida: o celular estava no cabo USB o tempo todo.
- fps com tempestade e tráfego no Centro (build temporária de medição): build p50 3,9 ms, raster p50 6,4 ms, p90 abaixo de 7,6 ms, dentro dos 11,1 ms de 90 Hz.
