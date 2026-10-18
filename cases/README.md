# Temporarily parked cases

These case folders are kept here while new candidates are validated one at a time. Only folders under `cases/` are runnable.

Move any case folder back into `cases/` to restore it. No case files or configuration need changing. To restore all of them from the repository root:

```sh
mv cases_approved/*/ cases/
```

If the controller is already running in Docker, rebuild/recreate it as usual so it picks up the changed source files: `docker compose up --build -d`.
