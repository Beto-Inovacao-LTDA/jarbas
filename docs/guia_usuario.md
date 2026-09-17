# Guia do usuário — Jarbas

O Jarbas é um app que permite controlar sua casa (luzes, tomadas, etc.) por
voz, conversando com o seu Home Assistant. Funciona de dois jeitos: tocando
no microfone quando quiser, ou (num aparelho dedicado) só falando "OK
Jarbas" a qualquer momento.

## Antes de começar: o que você precisa

- O app instalado no celular
- O endereço do seu Home Assistant (o mesmo que você usa no navegador, ex.
  `http://192.168.15.13:8123`)
- Um **token de acesso de longa duração** do Home Assistant (veja como
  gerar um abaixo)

### Como gerar o token no Home Assistant

1. No Home Assistant, clique no seu perfil (ícone/nome no canto, geralmente
   embaixo à esquerda).
2. Role até **"Tokens de acesso de longa duração"**.
3. Clique em **"Criar token"**, dê um nome (ex. "Jarbas") e confirme.
4. Copie o token na hora — o Home Assistant só mostra ele uma vez.

## Configurando o app pela primeira vez

1. Abra o Jarbas e toque no ícone de engrenagem ⚙️ no canto superior
   direito.
2. Em **"URL do Home Assistant"**, digite o endereço completo (com
   `http://` e a porta, ex. `http://192.168.15.13:8123`).
3. Em **"Token"**, cole o token que você gerou.
4. Toque em **"Testar conexão"** — deve aparecer "Conexão bem-sucedida". Se
   der erro, veja a seção de problemas comuns mais abaixo.
5. Toque em **"Salvar"**.

Pronto, o app já está pronto pra uso no modo sob demanda.

## Usando o modo sob demanda

Essa é a tela principal do app.

- **Toque no botão do microfone** (círculo roxo no meio da tela), fale o
  comando naturalmente (ex. "acender a luz da sala") e solte — o app
  transcreve e manda pro Home Assistant automaticamente, sem precisar
  apertar "enviar". A resposta do Home Assistant aparece na tela.
- Toque de novo no microfone (agora vermelho) se quiser parar de ouvir
  antes da hora.

### Atalhos

Embaixo do microfone tem uma grade de botões — os atalhos. Cada um dispara
um comando fixo direto, sem precisar falar nada. São úteis pra comandos que
você usa toda hora.

**Para adicionar um atalho:**
1. Vá em ⚙️ Configurações.
2. Role até "Atalhos", preencha **"Nome do atalho"** (o que aparece no
   botão) e **"Frase de comando"** (o texto que será enviado, como se você
   tivesse falado).
3. Toque em **"Adicionar atalho"**.

**Para remover:** toque no ícone de lixeira ao lado do atalho, na mesma
tela.

## Usando o Modo Jarbas

O Modo Jarbas deixa um aparelho (geralmente um celular antigo, sempre na
tomada) escutando continuamente, mesmo com a tela apagada, esperando você
dizer **"OK Jarbas"**. Ao ouvir, ele avisa com uma vibração/bipe curto,
escuta o comando seguinte e manda pro Home Assistant — sem você tocar em
nada.

A detecção da palavra de ativação funciona **100% offline** (não precisa de
internet nem de conta em nenhum serviço externo) — o modelo de
reconhecimento já vem embutido no app.

**Para ativar:**
1. Na tela principal, toque no interruptor ao lado de "Modo Jarbas".
2. Na primeira vez, o Android vai pedir permissão de notificação — aceite
   (é assim que você sabe que o Modo Jarbas está ativo: uma notificação
   fica fixa enquanto ele escuta).
3. Diga "OK Jarbas" e, depois de ouvir o feedback, fale seu comando.

**Para desativar:** toque no mesmo interruptor de novo.

### Dica: deixe o aparelho dedicado sempre carregando

Se você for usar o Modo Jarbas 24 horas por dia num celular fixo, vale
desativar a "otimização de bateria" desse app nas configurações do
Android, pra o sistema não derrubar o serviço sozinho. O caminho varia por
fabricante, mas geralmente é: Configurações do Android → Apps → Jarbas →
Bateria → sem restrições.

## Dicas pra comandos funcionarem melhor

- **Fale naturalmente**, como você falaria com uma pessoa: "acender a luz
  da sala", "desligar a tomada da cozinha".
- Se o app disser algo como "não existe nenhum dispositivo ou entidade com
  esse nome", o problema geralmente é o **nome do dispositivo no Home
  Assistant**, não o app. Dispositivos com nome técnico contendo `_`
  (underscore) são difíceis de reconhecer por voz, porque ninguém fala o
  "underscore" — por exemplo, `spot_mesa` funciona melhor com um apelido
  "spot mesa" cadastrado no próprio Home Assistant (Configurações → Vozes
  → Expor entidades no Assist, ou editando a entidade e adicionando um
  apelido).
- Teste o mesmo texto direto no Assist do Home Assistant (o balãozinho de
  conversa no app/site do HA) se quiser confirmar se o problema é o nome
  da entidade ou outra coisa.

## Problemas comuns

**"Testar conexão" ou o microfone dão "Falha na conexão"**
- Confira se a URL está completa (com `http://` e a porta).
- Confira se o celular está na mesma rede do Home Assistant (ou conectado
  via Tailscale/VPN, se você usa isso fora de casa).
- Confira se o token não expirou ou foi revogado no Home Assistant.

**Aparece "Token inválido ou não autorizado"**
- O token foi digitado errado, expirou, ou foi apagado no Home Assistant.
  Gere um novo (veja o início deste guia) e salve de novo.

**O microfone não escuta nada**
- Confirme que você deu permissão de microfone ao app (o Android costuma
  perguntar na primeira vez que você toca no botão).

**Modo Jarbas não liga / desliga sozinho**
- Confirme que você deu permissão de microfone ao app — sem ela, o Modo
  Jarbas não consegue nem começar a escutar e se desliga sozinho, com uma
  mensagem explicando o motivo.
- Se a mensagem mencionar erro ao carregar o modelo de reconhecimento, pode
  ser uma instalação corrompida do app — tente reinstalar.

## Precisa de ajuda?

Esse é um projeto pessoal, mantido pelo próprio Beto (Beto Engenharia e
Inovação). Se algo não funcionar como esperado, é só chamar.
