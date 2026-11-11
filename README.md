# KateringKita Monorepo

| Folder      | Repo asal                                            |
|-------------|------------------------------------------------------|
| `backend/`  | https://github.com/stanlevv/kateringkita-backend    |
| `frontend/` | https://github.com/stanlevv/kateringkita-frontend   |
| `mobile/`   | https://github.com/rohanrifqii/kateringkita-mobile  |

Tiap folder disinkron dengan repo asalnya lewat `git subtree`.

Ambil perubahan terbaru dari repo asal:

```sh
git subtree pull --prefix=backend backend main
git subtree pull --prefix=frontend frontend main
git subtree pull --prefix=mobile mobile main
```

Kirim perubahan ke repo asal:

```sh
git subtree push --prefix=backend backend main
git subtree push --prefix=frontend frontend main
git subtree push --prefix=mobile mobile main
```

Jangan ganti nama folder `backend/` menjadi `be/`: history repo backend
memuat anotasi `git-subtree-dir: be` lama yang membuat `git subtree split` gagal.
