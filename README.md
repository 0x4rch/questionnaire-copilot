# Questionnaire Copilot

A self-hosted Phoenix LiveView application that helps security/compliance professionals answer vendor security questionnaires faster by maintaining a searchable library of canonical Q&A pairs and matching them against incoming questionnaires.

## Prerequisites

- Erlang 27+
- Elixir 1.18+ (OTP 27)
- Docker & Docker Compose (for PostgreSQL)

### Installing Erlang & Elixir

Using [mise](https://mise.jdx.dev/):

```bash
mise use erlang@27 elixir@1.18
```

Or [asdf](https://asdf-vm.com/):

```bash
asdf plugin add erlang
asdf plugin add elixir
asdf install erlang 27.2
asdf install elixir 1.18.3-otp-27
asdf set erlang 27.2
asdf set elixir 1.18.3-otp-27
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
