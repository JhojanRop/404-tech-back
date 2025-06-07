Recopilando información del área de trabajo# Documentación de la API Backend

## Descripción General
Esta es una aplicación Ruby on Rails que funciona como backend para un sistema de recomendaciones de productos tecnológicos. La aplicación utiliza Firebase Firestore como base de datos y está configurada con CORS para permitir el acceso desde frontends externos.

## Estructura del Proyecto

### Arquitectura
- **Framework**: Ruby on Rails (API mode)
- **Base de datos**: Firebase Firestore
- **Autenticación**: JWT (opcional/comentada)
- **CORS**: Configurado para permitir todos los orígenes

### Controladores Principales

#### `ProductsController`
Maneja la gestión de productos tecnológicos.

**Endpoints**:
- `GET /products` - Lista todos los productos con paginación, filtros y ordenamiento
- `GET /products/:id` - Obtiene un producto específico
- `POST /products` - Crea un nuevo producto (requiere autenticación admin/editor)
- `PUT /products/:id` - Actualiza un producto (requiere autenticación admin/editor)
- `DELETE /products/:id` - Elimina un producto (requiere autenticación admin/editor)
- `GET /products/categories` - Obtiene todas las categorías disponibles

**Parámetros de filtrado**:
- `page`: Número de página (por defecto: 1)
- `limit`: Productos por página (por defecto: 20)
- `sort`: Ordenamiento (`best_rating`, `newest`, `price_low_to_high`, `price_high_to_low`)
- `categories`: Filtro por categorías

#### `RecommendationsController`
Sistema de recomendaciones basado en perfiles de usuario.

**Endpoints**:
- `POST /recommendations` - Genera recomendaciones basadas en un perfil
- `GET /recommendations/user/:user_id` - Obtiene recomendaciones para un usuario específico
- `POST /recommendations/feedback` - Envía feedback sobre recomendaciones

**Algoritmo de Recomendaciones**:
El sistema utiliza múltiples factores para calcular puntuaciones de coincidencia:
- Uso del producto (gaming, trabajo, estudio)
- Presupuesto del usuario
- Experiencia técnica
- Prioridades (rendimiento, precio, portabilidad)
- Preferencias de gaming
- Compatibilidad de software

#### `UserProfilesController`
Gestiona los perfiles de preferencias de usuarios.

**Endpoints**:
- `GET /user_profiles` - Lista todos los perfiles
- `GET /user_profiles/:id` - Obtiene un perfil específico
- `POST /user_profiles` - Crea un nuevo perfil de usuario
- `PUT /user_profiles/:id` - Actualiza un perfil
- `DELETE /user_profiles/:id` - Elimina un perfil
- `GET /user_profiles/by_user/:user_id` - Obtiene perfil por ID de usuario
- `PUT /user_profiles/by_user/:user_id` - Actualiza perfil por ID de usuario

#### `UsersController`
Maneja la gestión de usuarios y autenticación.

**Endpoints**:
- `GET /users` - Lista usuarios
- `GET /users/:id` - Obtiene un usuario específico
- `POST /users` o `POST /register` - Registra un nuevo usuario
- `PUT /users/:id` - Actualiza un usuario
- `DELETE /users/:id` - Elimina un usuario
- `POST /login` - Autenticación de usuario

#### `OrdersController`
Gestiona los pedidos de productos.

**Endpoints**:
- `GET /orders` - Lista pedidos
- `GET /orders/:id` - Obtiene un pedido específico
- `POST /orders` - Crea un nuevo pedido
- `PUT /orders/:id` - Actualiza un pedido (requiere autenticación admin/editor/support)
- `DELETE /orders/:id` - Elimina un pedido (requiere autenticación admin/editor/support)

#### `DiscountCodesController`
Maneja códigos de descuento.

**Endpoints**:
- `POST /discount_codes` - Crea un código de descuento
- `POST /discount_codes/:id/consume` - Consume/aplica un código de descuento

#### `ProductProfilesController`
Gestiona perfiles detallados de productos para el sistema de recomendaciones.

**Endpoints**:
- `GET /product_profiles` - Lista perfiles de productos
- `GET /product_profiles/:id` - Obtiene un perfil específico
- `POST /product_profiles` - Crea un perfil de producto
- `PUT /product_profiles/:id` - Actualiza un perfil
- `DELETE /product_profiles/:id` - Elimina un perfil

### Modelos

#### `Product`
Representa un producto tecnológico con los siguientes atributos:
- `name`: Nombre del producto (obligatorio)
- `price`: Precio (obligatorio)
- `category`: Categoría (obligatorio)
- `description`: Descripción
- `discount`: Descuento aplicable
- `stock`: Cantidad en inventario
- `rating`: Calificación (por defecto: 0.0)
- `usage`: Array de usos del producto
- `images`: Array de URLs de imágenes
- `specs`: Hash de especificaciones técnicas

#### `Order`
Representa un pedido con:
- `user_id`: ID del usuario
- `products`: Array de productos
- `shipping`: Información de envío
- `status`: Estado del pedido
- `total`: Total del pedido
- `created_at`: Fecha de creación

### Servicios

#### `RecommendationEngine`
Motor de recomendaciones que implementa algoritmos para:
- Calcular puntuaciones de coincidencia entre usuarios y productos
- Generar razones para las recomendaciones
- Manejar diferentes tipos de perfiles de productos
- Aplicar factores de precio, gaming, portabilidad y uso

### Configuración

#### CORS
El archivo cors.rb está configurado para permitir:
- Orígenes: `*` (todos los orígenes)
- Métodos: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
- Headers: Cualquiera
- Exposición del header `Authorization`

#### Rutas
Las rutas están definidas en routes.rb y incluyen:
- Recursos RESTful para todos los controladores principales
- Rutas personalizadas para autenticación (`/login`, `/register`)
- Rutas anidadas para perfiles por usuario
- Endpoint de salud de la aplicación (`/up`)

## Sistema de Recomendaciones

### Algoritmo Principal
El sistema utiliza un enfoque híbrido:

1. **Puntuación basada en perfil**: Si existe un perfil detallado del producto
2. **Puntuación básica**: Basada en nombre, categoría y especificaciones
3. **Puntuación de precio**: Según el presupuesto del usuario
4. **Normalización**: Puntuaciones de 0-100%

### Factores de Puntuación

#### Gaming
- **Casual**: Productos entry-level y mid-range (+15-20 puntos)
- **Regular**: Productos mid-range y high-end (+15-25 puntos)
- **Hardcore**: Solo productos high-end (+25 puntos)

#### Portabilidad
- **Laptop**: Bonus para laptops (+25), penalty mínima para desktops
- **Desktop**: Bonus para desktops (+25), complementarios útiles
- **Either**: Bonus equilibrado para ambos

#### Presupuesto
- **Low**: Productos < $600 obtienen mayor puntuación
- **Medium**: Productos $400-$1200 son óptimos
- **High**: Productos $1000-$2500 son preferidos
- **Unlimited**: Productos > $1000 son favorecidos

## Autenticación y Autorización

### Sistema JWT (Opcional)
La autenticación está implementada pero comentada en varios controladores. Incluye:
- Middleware de autorización por roles
- Tokens JWT para sesiones
- Roles: admin, editor, support

### Niveles de Acceso
- **Público**: Consulta de productos, recomendaciones, registro
- **Admin/Editor**: Gestión completa de productos y perfiles
- **Support**: Gestión de pedidos

## Base de Datos (Firestore)

### Colecciones Principales
- `products`: Productos del catálogo
- `users`: Usuarios registrados
- `user_profiles`: Perfiles de preferencias
- `product_profiles`: Perfiles detallados de productos
- `orders`: Pedidos realizados
- `discount_codes`: Códigos de descuento

### Estructura de Datos
Cada documento en Firestore incluye:
- Campos de datos específicos del modelo
- `createdAt`: Timestamp de creación
- `updatedAt`: Timestamp de última actualización
- ID generado automáticamente por Firestore

## Deployment y Configuración

### Variables de Entorno
- `SECRET_KEY_BASE`: Clave para JWT
- Credenciales de Firebase en credentials.yml.enc

### Archivos de Error
El directorio public contiene páginas de error personalizadas:
- `400.html`: Bad Request
- `422.html`: Unprocessable Entity
- `500.html`: Internal Server Error

### Logging
La aplicación utiliza `Rails.logger` extensivamente para debugging del sistema de recomendaciones y operaciones de Firestore.

## Ejemplos de Uso

### Crear Recomendaciones
```bash
POST /recommendations
{
  "user_id": "123",
  "usage": "gaming",
  "budget": "medium",
  "experience": "intermediate",
  "priority": "performance",
  "portability": "desktop",
  "gaming": "regular"
}
```

### Filtrar Productos
```bash
GET /products?categories[]=gaming&sort=best_rating&page=1&limit=10
```

### Obtener Recomendaciones por Usuario
```bash
GET /recommendations/user/123
```

Esta documentación proporciona una visión completa del sistema y puede ser utilizada tanto por desarrolladores que trabajen en el proyecto como por equipos que necesiten integrar con la API.