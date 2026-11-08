<?xml version="1.0" encoding="UTF-8"?>
<!--
  How a browser draws /sitemap.xml: a page that groups the addresses by language and country, with the other
  versions of each page one click away. Search engines ignore this file and read the XML.

  Served by QuickSlipsWeb.SitemapController at /sitemap.xsl, and named in the XML by an xml-stylesheet instruction
  (QuickSlipsWeb.Sitemap). XSLT is on its way out of browsers (Chrome stops running it for everyone on 17 November
  2026; Firefox and Safari have said they will follow), and then a browser shows the plain XML tree again. The page
  that always works is /sitemap (QuickSlipsWeb.SitemapLive).

  XSLT 1.0, which is all a browser has. The grouping is the Muenchian method: a key on the first part of the path
  ("en-in" in https://host/en-in/fuel-bill-generator), and the first url of each key is the head of its group.
-->
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:sm="http://www.sitemaps.org/schemas/sitemap/0.9"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="sm xhtml">

  <xsl:output method="html" encoding="UTF-8" indent="no" doctype-system="about:legacy-compat"/>

  <xsl:key name="by-locale" match="sm:url"
           use="substring-before(concat(substring-after(substring-after(sm:loc, '//'), '/'), '/'), '/')"/>

  <xsl:template match="/sm:urlset">
    <xsl:variable name="heads"
        select="sm:url[generate-id() = generate-id(key('by-locale', substring-before(concat(substring-after(substring-after(sm:loc, '//'), '/'), '/'), '/'))[1])]"/>
    <html lang="en">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>Sitemap · QuickSlips</title>
        <link rel="icon" href="/favicon.ico" sizes="32x32"/>
        <style>
          :root {
            color-scheme: light dark;
            --page: #f8f6f1; --surface: #fdfcf9; --muted: #f0ede5; --ink: #1d2420; --ink-2: #4b554f;
            --line: #e4e0d6; --primary: #177457; --primary-soft: #e3f1ec; --accent: #b85a0c;
          }
          @media (prefers-color-scheme: dark) {
            :root {
              --page: #0f1512; --surface: #171d1a; --muted: #1f2723; --ink: #f1f1ea; --ink-2: #b9c0ba;
              --line: #2b3530; --primary: #46c9a0; --primary-soft: #1c3a31; --accent: #f0954a;
            }
          }
          * { box-sizing: border-box; }
          body {
            margin: 0; background: var(--page); color: var(--ink);
            font: 16px/1.55 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", sans-serif;
          }
          a { color: var(--primary); text-decoration: none; }
          a:hover { text-decoration: underline; }
          .wrap { max-width: 960px; margin: 0 auto; padding: 32px 20px 56px; }
          .brand { display: inline-block; }
          .brand img { display: block; height: 32px; width: auto; }
          .brand .on-dark { display: none; }
          @media (prefers-color-scheme: dark) {
            .brand .on-light { display: none; }
            .brand .on-dark { display: block; }
          }
          h1 { font-size: 30px; line-height: 1.2; letter-spacing: -0.01em; margin: 22px 0 6px; }
          .lead { margin: 0; max-width: 62ch; color: var(--ink-2); }
          .stats { display: flex; flex-wrap: wrap; gap: 10px; list-style: none; margin: 20px 0 8px; padding: 0; }
          .stats li { background: var(--primary-soft); border-radius: 999px; padding: 6px 14px; font-size: 14px; }
          .stats b { font-weight: 700; }
          .hint { margin: 6px 0 0; font-size: 14px; color: var(--ink-2); }
          main { display: grid; gap: 12px; margin-top: 24px; }
          details.locale { background: var(--surface); border: 1px solid var(--line); border-radius: 14px; overflow: hidden; }
          details.locale > summary {
            display: flex; align-items: center; gap: 12px; padding: 14px 18px;
            cursor: pointer; list-style: none; font-weight: 600;
          }
          details.locale > summary::-webkit-details-marker { display: none; }
          details.locale > summary::before { content: "\25B8"; color: var(--ink-2); font-size: 14px; transition: transform 0.15s; }
          details.locale[open] > summary::before { transform: rotate(90deg); }
          details.locale > summary:hover { background: var(--muted); }
          .code { font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; color: var(--ink-2); background: var(--muted); border-radius: 6px; padding: 2px 7px; }
          .count { margin-left: auto; font-size: 13px; font-weight: 500; color: var(--ink-2); background: var(--muted); border-radius: 999px; padding: 2px 10px; }
          ul.pages { list-style: none; margin: 0; padding: 6px 18px 14px; border-top: 1px solid var(--line); }
          li.page { padding: 9px 0; border-bottom: 1px solid var(--line); }
          li.page:last-child { border-bottom: 0; }
          .row { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; }
          .path { font: 14px ui-monospace, SFMono-Regular, Menlo, monospace; word-break: break-all; }
          .tag { font-size: 11px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; color: var(--accent); border: 1px solid var(--accent); border-radius: 6px; padding: 0 6px; }
          details.versions { margin-top: 2px; }
          details.versions > summary { display: inline-block; cursor: pointer; list-style: none; font-size: 13px; color: var(--ink-2); }
          details.versions > summary::-webkit-details-marker { display: none; }
          details.versions > summary::after { content: " \25BE"; }
          details.versions[open] > summary::after { content: " \25B4"; }
          ul.alts { list-style: none; margin: 6px 0 2px; padding: 0; display: grid; gap: 4px; }
          ul.alts li { display: flex; gap: 10px; align-items: baseline; font-size: 13px; }
          .lang { flex: 0 0 68px; font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; color: var(--ink-2); }
          .self .lang { color: var(--primary); font-weight: 700; }
          ul.alts a { word-break: break-all; }
          footer { margin-top: 32px; font-size: 13px; color: var(--ink-2); }
        </style>
      </head>
      <body>
        <div class="wrap">
          <header>
            <a class="brand" href="/" aria-label="QuickSlips">
              <img class="on-light" src="/images/logo.svg" alt="QuickSlips"/>
              <img class="on-dark" src="/images/logo-on-dark.svg" alt="QuickSlips"/>
            </a>
            <h1>Sitemap</h1>
            <p class="lead">
              Every public page of QuickSlips, grouped by language and country. Search engines read this
              same list as XML; this is how a browser can show it.
            </p>
            <ul class="stats">
              <li><b><xsl:value-of select="format-number(count(sm:url), '#,##0')"/></b> pages</li>
              <li><b><xsl:value-of select="count($heads)"/></b> languages and countries</li>
              <li><b><xsl:value-of select="format-number(count(sm:url/xhtml:link), '#,##0')"/></b> links between versions</li>
            </ul>
            <p class="hint">Prefer a plain page? <a href="/sitemap">Open the sitemap page</a>.</p>
          </header>

          <main>
            <xsl:for-each select="$heads">
              <xsl:call-template name="locale">
                <xsl:with-param name="code" select="substring-before(concat(substring-after(substring-after(sm:loc, '//'), '/'), '/'), '/')"/>
              </xsl:call-template>
            </xsl:for-each>
          </main>

          <footer>The XML itself is at this same address; <a href="/robots.txt">robots.txt</a> points search engines to it.</footer>
        </div>
      </body>
    </html>
  </xsl:template>

  <!-- One language and country: its pages, each with its other versions. -->
  <xsl:template name="locale">
    <xsl:param name="code"/>
    <xsl:variable name="pages" select="key('by-locale', $code)"/>
    <details class="locale">
      <summary>
        <span>
          <xsl:call-template name="locale-name">
            <xsl:with-param name="code" select="$code"/>
          </xsl:call-template>
        </span>
        <span class="code"><xsl:value-of select="$code"/></span>
        <span class="count"><xsl:value-of select="count($pages)"/> pages</span>
      </summary>
      <ul class="pages">
        <xsl:for-each select="$pages">
          <xsl:variable name="loc" select="sm:loc"/>
          <xsl:variable name="path" select="substring-after(substring-after($loc, '//'), '/')"/>
          <li class="page">
            <div class="row">
              <a class="path" href="{$loc}">/<xsl:value-of select="$path"/></a>
              <!-- a path with no second part is the catalogue of the locale -->
              <xsl:if test="not(contains($path, '/'))"><span class="tag">Catalogue</span></xsl:if>
            </div>
            <details class="versions">
              <summary><xsl:value-of select="count(xhtml:link[@hreflang != 'x-default'])"/> versions</summary>
              <ul class="alts">
                <xsl:for-each select="xhtml:link">
                  <li>
                    <xsl:if test="@href = $loc"><xsl:attribute name="class">self</xsl:attribute></xsl:if>
                    <span class="lang"><xsl:value-of select="@hreflang"/></span>
                    <a href="{@href}"><xsl:value-of select="@href"/></a>
                  </li>
                </xsl:for-each>
              </ul>
            </details>
          </li>
        </xsl:for-each>
      </ul>
    </details>
  </xsl:template>

  <!-- What a person calls a locale: the language in its own name, then the country. -->
  <xsl:template name="locale-name">
    <xsl:param name="code"/>
    <xsl:choose>
      <xsl:when test="$code = 'en-in'">English · India</xsl:when>
      <xsl:when test="$code = 'hi-in'">हिन्दी · India</xsl:when>
      <xsl:when test="$code = 'es-es'">Español · Spain</xsl:when>
      <xsl:when test="$code = 'en-us'">English · United States</xsl:when>
      <xsl:when test="$code = 'zh-cn'">简体中文 · China</xsl:when>
      <xsl:when test="$code = 'de-de'">Deutsch · Germany</xsl:when>
      <xsl:when test="$code = 'ja-jp'">日本語 · Japan</xsl:when>
      <xsl:when test="$code = 'en-gb'">English · United Kingdom</xsl:when>
      <xsl:when test="$code = 'fr-fr'">Français · France</xsl:when>
      <xsl:when test="$code = 'it-it'">Italiano · Italy</xsl:when>
      <xsl:when test="$code = 'pt-br'">Português · Brazil</xsl:when>
      <xsl:when test="$code = 'en-ca'">English · Canada</xsl:when>
      <xsl:when test="$code = 'fr-ca'">Français · Canada</xsl:when>
      <xsl:otherwise><xsl:value-of select="$code"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
