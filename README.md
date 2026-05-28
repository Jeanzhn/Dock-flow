# 📦 Dock Flow

Um projeto logístico desenvolvido em Flutter para otimização de filas e controle de fluxo operacional de docas.

---

## 📚 Getting Started (Primeiros Passos)

Este projeto é um ponto de partida para uma aplicação Flutter. Se este é o seu primeiro projeto, aqui estão alguns recursos úteis:

* [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
* [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
* [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

Para obter ajuda na configuração do ambiente de desenvolvimento, consulte a [documentação online oficial](https://docs.flutter.dev/), que oferece tutoriais, exemplos e referência completa da API.

---

## 🚀 Como Configurar e Rodar o Projeto Localmente

### 📌 Pré-requisitos

Antes de começar, certifique-se de que sua máquina possui as seguintes ferramentas:
* **SDK do Flutter** instalado e configurado nas Variáveis de Ambiente.
* **Node.js** (Versão LTS) instalado.
* **Conta Google** com acesso concedido ao projeto Firebase (`dockflow-cd84e`).

### 🛠️ Passo a Passo de Instalação

**1. Clone o repositório e baixe as dependências**
Abra o terminal na pasta raiz do projeto clonado e instale os pacotes mapeados no `pubspec.yaml`:
```bash
git pull
flutter clean
flutter pub get
```

**2. Instale o motor principal do Firebase (CLI)**
No mesmo terminal, utilize o Node.js para instalar as ferramentas globais do Firebase:
```bash
npm install -g firebase-tools
```

**3. Faça o Login na sua Conta Google**
Autentique sua máquina para ter permissão de acessar o banco de dados da nuvem. Uma aba do navegador se abrirá:
```bash
firebase login
```

**4. Instale o integrador nativo do Flutter (FlutterFire)**
Ative a ferramenta do Google projetada para unir o Flutter ao Firebase automaticamente:
```bash
dart pub global activate flutterfire_cli
```

**5. Gere as Chaves de Conexão**
> ⚠️ **Atenção:** O arquivo `firebase_options.dart` não é enviado para o GitHub por motivos de segurança. Você precisa gerá-lo localmente (esta etapa é **obrigatória** ao configurar o projeto em uma máquina nova).

Execute o comando abaixo apontando para o nosso projeto:
```bash
dart pub global run flutterfire_cli:flutterfire configure --project=dockflow-cd84e
```
*Quando solicitado no terminal, selecione as plataformas desejadas (Android, iOS, Web) apertando **Enter**.*

**6. Rode a Aplicação**
Com as chaves geradas e o ambiente configurado, o projeto está pronto para teste:
```bash
flutter run
```
> 💡 **Nota:** Caso ocorram erros de permissão de pasta no Windows durante a compilação, feche a sua IDE (VS Code/Android Studio), abra um novo terminal na pasta do projeto e tente rodar o comando novamente.