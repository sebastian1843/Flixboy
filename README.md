# 🎬 Streaming Platform — NestJS Backend

Backend completo para una plataforma de streaming (tipo Netflix/Prime Video) construido con **NestJS**, **PostgreSQL**, **TypeORM** y **Redis**.

---

## 🏗️ Arquitectura

```
src/
├── auth/               # JWT + Refresh tokens + estrategias Passport
├── users/              # Gestión de cuentas de usuario
├── profiles/           # Hasta 4 perfiles por cuenta, con PIN y restricciones de edad
├── content/            # Películas, series, documentales + temporadas + episodios
├── categories/         # Géneros y categorías de contenido
├── watchlist/          # Mi Lista + historial de reproducción + progreso
├── recommendations/    # Motor de recomendaciones personalizadas por perfil
├── streaming/          # Resolución de URLs de video (firmadas/CDN) por calidad
├── search/             # Búsqueda full-text + autocompletado
├── database/           # Seeder con géneros y contenido de ejemplo
└── common/             # Filtros, interceptores, decoradores compartidos
```

### Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Framework | NestJS 10 |
| Base de datos | PostgreSQL 15 + TypeORM |
| Caché | Redis 7 + cache-manager |
| Autenticación | JWT (access + refresh tokens) + Passport |
| Validación | class-validator + class-transformer |
| Documentación | Swagger / OpenAPI |
| Rate limiting | @nestjs/throttler |
| Almacenamiento | AWS S3 + CloudFront (configurable) |
| Contenedores | Docker + Docker Compose |

---

## 🚀 Inicio rápido

### 1. Prerrequisitos

- Node.js 20+
- Docker y Docker Compose

### 2. Clonar y configurar

```bash
# Copiar variables de entorno
cp .env.example .env
# Editar .env con tus valores (JWT_SECRET, DB_PASSWORD, etc.)
```

### 3. Levantar con Docker

```bash
docker-compose up -d
```

La API estará disponible en `http://localhost:3000/api/v1`  
Swagger UI: `http://localhost:3000/docs`

### 4. Seed inicial (géneros + contenido de ejemplo)

```bash
npm run seed
```

### 5. Desarrollo local sin Docker

```bash
# Instalar dependencias
npm install

# Necesitas PostgreSQL y Redis corriendo localmente
npm run start:dev
```

---

## 📡 Endpoints principales

### Auth
```
POST /api/v1/auth/register     Crear cuenta
POST /api/v1/auth/login        Iniciar sesión → access + refresh tokens
POST /api/v1/auth/logout       Cerrar sesión
POST /api/v1/auth/refresh      Renovar access token
GET  /api/v1/auth/me           Usuario autenticado
```

### Perfiles (máx. 4 por cuenta)
```
GET    /api/v1/profiles         Listar perfiles
POST   /api/v1/profiles         Crear perfil
PATCH  /api/v1/profiles/:id     Actualizar perfil
DELETE /api/v1/profiles/:id     Eliminar perfil
POST   /api/v1/profiles/:id/verify-pin   Verificar PIN
```

### Contenido
```
GET  /api/v1/content/home           Página principal (filas por categoría)
GET  /api/v1/content/trending       Tendencias
GET  /api/v1/content/new            Novedades
GET  /api/v1/content/originals      Producciones originales
GET  /api/v1/content/:id            Ficha completa (sinopsis, elenco, temporadas...)
GET  /api/v1/content/:id/seasons    Temporadas y episodios
GET  /api/v1/content               Catálogo con filtros y paginación
POST /api/v1/content               Crear contenido (admin)
```

### Recomendaciones
```
GET  /api/v1/recommendations/profiles/:profileId/home     Home personalizado
GET  /api/v1/recommendations/content/:contentId/similar   Contenido similar
```

### Streaming
```
GET  /api/v1/streaming/:contentId/url        URL firmada de video
GET  /api/v1/streaming/:contentId/manifest   Manifest HLS/DASH
     ?quality=auto|sd|hd|4k
     ?episodeId=<uuid>   (requerido para series)
```

### Mi Lista e Historial
```
GET    /api/v1/profiles/:profileId/watchlist           Mi lista
POST   /api/v1/profiles/:profileId/watchlist/:id       Agregar
DELETE /api/v1/profiles/:profileId/watchlist/:id       Quitar
GET    /api/v1/profiles/:profileId/history             Historial
GET    /api/v1/profiles/:profileId/continue-watching   Seguir viendo
POST   /api/v1/profiles/:profileId/progress            Actualizar progreso
GET    /api/v1/profiles/:profileId/progress/:contentId Progreso de un título
```

### Búsqueda
```
GET  /api/v1/search?q=inception&type=movie&minRating=7
GET  /api/v1/search/autocomplete?q=gal
GET  /api/v1/search/popular
```

---

## 🧠 Motor de recomendaciones

El algoritmo combina múltiples señales por perfil:

1. **Géneros preferidos** — configurados al crear/editar el perfil
2. **Historial de visualización** — categorías de los últimos títulos completados
3. **Filtro de no-vistos** — excluye contenido ya visto
4. **Boost por originales y rating** — prioriza contenido exclusivo y bien valorado
5. **Filas de género** — hasta 3 filas temáticas basadas en los géneros favoritos
6. **Caché Redis** — resultados cacheados 5 minutos para evitar recalcular en cada carga

Filas generadas en `/recommendations/profiles/:id/home`:
- Seguir viendo
- Recomendado para ti
- Porque viste (basado en historial)
- Tendencias que no has visto
- Novedades
- Originales
- [Género 1], [Género 2], [Género 3]

---

## 🔐 Autenticación

Flujo JWT con doble token:

```
Login → { accessToken (7d), refreshToken (30d) }
      ↓
Requests → Authorization: Bearer <accessToken>
      ↓
Expirado → POST /auth/refresh  { userId, refreshToken }
         → { nuevos tokens }
```

---

## 📦 Variables de entorno clave

| Variable | Descripción |
|----------|-------------|
| `JWT_SECRET` | Clave para firmar access tokens |
| `JWT_REFRESH_SECRET` | Clave para firmar refresh tokens |
| `DB_*` | Conexión a PostgreSQL |
| `REDIS_*` | Conexión a Redis |
| `AWS_CLOUDFRONT_URL` | Base URL del CDN para URLs firmadas |
| `AWS_S3_BUCKET` | Bucket donde están los archivos de video |

---

## 🐳 Comandos útiles

```bash
# Producción
docker-compose -f docker-compose.yml up -d --build

# Ver logs
docker-compose logs -f api

# Acceder a la base de datos
docker exec -it streaming_postgres psql -U postgres -d streaming_db

# Ejecutar tests
npm run test
npm run test:e2e
```

---

## 🗺️ Próximos pasos sugeridos

- [ ] Roles y permisos (admin / usuario)
- [ ] Rating y reseñas de contenido por perfil
- [ ] Notificaciones push (nuevo contenido por género favorito)
- [ ] Integración de pagos (Stripe) para planes de suscripción
- [ ] Subtítulos dinámicos (.vtt / WebVTT desde S3)
- [ ] ABR real con HLS (AWS MediaConvert / ffmpeg pipeline)
- [ ] Analytics de visualización (tiempo total, device breakdown)
- [ ] Tests unitarios y e2e completos
