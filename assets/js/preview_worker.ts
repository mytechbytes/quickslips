import { $typst } from "@myriaddreamin/typst.ts"

type Job = { id: number; source: string; data: unknown }

// Tell typst.ts where to fetch its two WASM modules from (our own server).
$typst.setCompilerInitOptions({
  getModule: () => "/wasm/typst_ts_web_compiler_bg.wasm",
})
$typst.setRendererInitOptions({
  getModule: () => "/wasm/typst_ts_renderer_bg.wasm",
})

self.onmessage = async (event: MessageEvent<Job>) => {
  const { id, source, data } = event.data
  try {
    // Same layout as on the server: main.typ with data.json next to it.
    await $typst.mapShadow("/data.json", new TextEncoder().encode(JSON.stringify(data)))
    await $typst.addSource("/main.typ", source)
    const svg = await $typst.svg({ mainFilePath: "/main.typ", inputs: { mode: "preview" } })
    self.postMessage({ id, svg })
  } catch (error) {
    self.postMessage({ id, error: String(error) })
  }
}
