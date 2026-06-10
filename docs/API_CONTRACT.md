# API Contract

This document fixes the JSON contract expected by the Angular front-end and maps each API-facing object to the current Ruby/Rails database schema.

The rule for the refactoring is:

- Angular-facing JSON uses `camelCase`.
- Rails models, database columns, services, and internal params use `snake_case`.
- Conversion between the two formats must happen only at the API boundary:
  - request parsing: `camelCase` JSON -> `snake_case` Rails params
  - response serialization: Rails model/data -> `camelCase` JSON