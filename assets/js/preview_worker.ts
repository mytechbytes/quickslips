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
    // Make data.json visible to the template, like the file next to main.typ on the server.
    await $typst.addSource("/data.json", JSON.stringify(data))
    const svg = await $typst.svg({ mainContent: source, inputs: { mode: "preview" } })
    self.postMessage({ id, svg })
  } catch (error) {
    self.postMessage({ id, error: String(error) })
  }
}
