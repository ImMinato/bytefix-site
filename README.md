# MachimusCORE — ByteFix

Sitio web oficial de MachimusCORE by ByteFix.

---

## 📁 Estructura del proyecto

```
bytefix-site/
├── index.html          ← Página principal (toda la lógica, CSS y JS incluidos)
├── README.md           ← Este archivo
├── .nojekyll           ← Necesario para GitHub Pages
├── assets/
│   ├── css/            ← Estilos extra (actualmente todo está inline en index.html)
│   ├── js/             ← Scripts extra (actualmente todo está inline en index.html)
│   └── img/            ← Imágenes futuras (logo, screenshots, etc.)
```

---

## 🚀 Cómo hospedar en GitHub Pages (GRATIS)

> GitHub Pages es **100% gratis** para sitios estáticos. No necesitás pagar nada.

### Paso 1 — Crear cuenta en GitHub
1. Entrá a [github.com](https://github.com) y creá una cuenta si no tenés.

### Paso 2 — Crear un repositorio
1. En GitHub, hacé clic en **"New repository"** (botón verde arriba a la derecha).
2. Nombre del repo: `bytefix-site` (o lo que quieras).
3. Que sea **Public** (necesario para GitHub Pages gratis).
4. Hacé clic en **"Create repository"**.

### Paso 3 — Subir los archivos desde Visual Studio Community

1. Abrí **Visual Studio Community**.
2. Instalá la extensión **Git** si no la tenés (viene incluida).
3. Abrí la carpeta `bytefix-site` como proyecto: `Archivo > Abrir > Carpeta`.
4. Abrí la terminal integrada: `Ver > Terminal` (o `Ctrl + ñ`).
5. Ejecutá estos comandos uno por uno:

```bash
git init
git add .
git commit -m "Primer commit - MachimusCORE website"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/bytefix-site.git
git push -u origin main
```

> ⚠️ Reemplazá `TU_USUARIO` con tu nombre de usuario de GitHub.

### Paso 4 — Activar GitHub Pages
1. En tu repositorio de GitHub, entrá a **Settings** (arriba a la derecha).
2. En el menú izquierdo, hacé clic en **Pages**.
3. En "Branch", seleccioná `main` y la carpeta `/root`.
4. Hacé clic en **Save**.
5. Esperá 1-2 minutos y tu sitio estará en:

```
https://TU_USUARIO.github.io/bytefix-site/
```

---

## 🌐 Dominio personalizado (opcional, también gratis)

Si querés tener algo como `bytefix.com` o `machimustcore.com`:
- Podés comprar un dominio en [Namecheap](https://namecheap.com) (~$10/año).
- Alternativamente, [Freenom](https://freenom.com) ofrece dominios `.tk`, `.ml` gratis.
- En GitHub Pages > Custom domain, escribís tu dominio y listo.

---

## 🛠️ Cómo editar el sitio

Toda la página está en **`index.html`**. Abrilo con Visual Studio Community y buscá:
- **Precios** → buscá `$8`, `$15`, `$30`
- **Número de WhatsApp** → buscá `5491164005097`
- **Instagram** → buscá `ByteFixBa`
- **Colores** → al principio del `<style>`, en las variables `:root`

---

## 📞 Contacto del proyecto

- WhatsApp: +54 9 11-6400-5097
- Instagram: [@ByteFixBa](https://instagram.com/ByteFixBa)


## 🌐 Dominio bytefixba.shop (IONOS + GitHub Pages)
1. En GitHub: repo → Settings → Pages → *Custom domain* → escribí `bytefixba.shop` → Save. (Hacelo ANTES de tocar el DNS: GitHub lo recomienda para evitar que alguien tome tu dominio.) El archivo `CNAME` de este repo ya dice `bytefixba.shop`.
2. En IONOS (Dominios → tu dominio → DNS), cargá estos registros:
   - **A** con nombre `@` para cada una de estas IP: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - **AAAA** con nombre `@` (opcional, IPv6): `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`
   - **CNAME** con nombre `www` apuntando a `TU-USUARIO.github.io` (sin el nombre del repo)
   - No uses registros comodín (`*`).
3. Esperá a que propague (hasta 24 h) y en Settings → Pages tildá **Enforce HTTPS**.
4. Recomendado: verificar el dominio en GitHub (Settings de tu cuenta → Pages → Add a domain).

## 📈 Estadísticas sin cookies (opcional)
Creá una cuenta gratis en goatcounter.com y poné tu código en `GC_CODE` (al final de `index.html`). Si lo activás, agregalo también en la sección de privacidad de `legal.html`.

## 🔐 Scanner público
`tools/SCAN_MACHIMUS.bat` y su hash en `tools/SHA256SUMS.txt`. Si modificás el scanner, recalculá el hash y actualizalo en `transparencia.html`:
`Get-FileHash .\tools\SCAN_MACHIMUS.bat -Algorithm SHA256`
