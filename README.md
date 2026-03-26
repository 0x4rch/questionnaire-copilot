# Questionnaire Copilot

A self-hosted Phoenix LiveView application that helps security/compliance professionals answer vendor security questionnaires faster by maintaining a searchable library of canonical Q&A pairs and matching them against incoming questionnaires.

## Prerequisites

- Erlang/OTP 28+
- Elixir 1.19+ (OTP 28)
- Docker & Docker Compose (for PostgreSQL)

### Installing Erlang & Elixir

Using [mise](https://mise.jdx.dev/):

```bash
mise use erlang@28 elixir@1.19
```

Or [asdf](https://asdf-vm.com/):

```bash
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 28.4.1
asdf install elixir 1.19.5-otp-28
asdf set erlang 28.4.1
asdf set elixir 1.19.5-otp-28
```

## Getting Started

```bash
# Start PostgreSQL
docker compose up -d

# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Start Phoenix server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

## Development

```bash
# Run tests
mix test

# Start interactive shell with server
iex -S mix phx.server

# Reset database
mix ecto.reset
```
