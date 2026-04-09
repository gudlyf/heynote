import crypto from "node:crypto"
import http from "node:http"
import { SCRATCH_FILE_NAME } from "../../src/common/constants"

let server = null
let fileLibrary = null
let apiToken = null
let browserWindow = null

function parseBody(req) {
    return new Promise((resolve, reject) => {
        const chunks = []
        req.on("data", (chunk) => chunks.push(chunk))
        req.on("end", () => {
            try {
                resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")))
            } catch (e) {
                reject(new Error("Invalid JSON"))
            }
        })
        req.on("error", reject)
    })
}

function jsonResponse(res, statusCode, data) {
    res.writeHead(statusCode, { "Content-Type": "application/json" })
    res.end(JSON.stringify(data))
}

function checkAuth(req, res) {
    const authHeader = req.headers["authorization"]
    if (!authHeader || authHeader !== `Bearer ${apiToken}`) {
        jsonResponse(res, 401, { error: "Unauthorized. Provide a valid Bearer token in the Authorization header." })
        return false
    }
    return true
}

async function handleAppend(req, res) {
    if (req.method !== "POST") {
        return jsonResponse(res, 405, { error: "Method not allowed" })
    }

    let body
    try {
        body = await parseBody(req)
    } catch (e) {
        return jsonResponse(res, 400, { error: "Invalid JSON body" })
    }

    const { text, path, language } = body
    if (!text || typeof text !== "string") {
        return jsonResponse(res, 400, { error: "\"text\" field is required and must be a string" })
    }

    const notePath = path || SCRATCH_FILE_NAME
    const blockLang = language || "text"
    const created = new Date().toISOString()
    const newBlock = `\n∞∞∞${blockLang};created=${created}\n${text}\n`

    try {
        const exists = await fileLibrary.exists(notePath)
        let newContent
        if (exists) {
            const content = await fileLibrary.load(notePath)
            newContent = content + newBlock
            await fileLibrary.save(notePath, newContent)
        } else {
            const metadata = JSON.stringify({
                formatVersion: "2.0.0",
                name: notePath.replace(/\.txt$/, ""),
            })
            newContent = metadata + `\n∞∞∞${blockLang};created=${created}\n${text}\n`
            await fileLibrary.create(notePath, newContent)
            // Load the newly created file so the library tracks it
            await fileLibrary.load(notePath)
        }

        // Notify the renderer that the buffer changed
        if (browserWindow && !browserWindow.isDestroyed()) {
            browserWindow.webContents.send("buffer:change", notePath, newContent)
        }

        return jsonResponse(res, 200, { ok: true, path: notePath })
    } catch (e) {
        console.error("API append error:", e)
        return jsonResponse(res, 500, { error: e.message })
    }
}

async function handleNotes(req, res) {
    if (req.method !== "GET") {
        return jsonResponse(res, 405, { error: "Method not allowed" })
    }
    try {
        const notes = await fileLibrary.getList()
        return jsonResponse(res, 200, { notes })
    } catch (e) {
        console.error("API notes list error:", e)
        return jsonResponse(res, 500, { error: e.message })
    }
}

async function handleRequest(req, res) {
    // Only allow requests from localhost
    res.setHeader("Access-Control-Allow-Origin", "http://127.0.0.1")
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

    if (req.method === "OPTIONS") {
        res.writeHead(204)
        return res.end()
    }

    if (!checkAuth(req, res)) {
        return
    }

    const url = new URL(req.url, `http://${req.headers.host}`)

    switch (url.pathname) {
        case "/api/append":
            return handleAppend(req, res)
        case "/api/notes":
            return handleNotes(req, res)
        default:
            return jsonResponse(res, 404, { error: "Not found" })
    }
}

/**
 * Generate a new API token if one doesn't already exist in config.
 */
export function ensureApiToken(config) {
    let token = config.get("settings.apiToken")
    if (!token) {
        token = crypto.randomBytes(32).toString("hex")
        config.set("settings.apiToken", token)
    }
    return token
}

export function startApiServer(library, port = 5095, token, win) {
    fileLibrary = library
    apiToken = token
    browserWindow = win
    if (server) {
        return
    }

    server = http.createServer(handleRequest)
    server.listen(port, "127.0.0.1", () => {
        console.log(`Heynote API server listening on http://127.0.0.1:${port}`)
    })
    server.on("error", (err) => {
        console.error("API server error:", err)
        server = null
    })
}

export function stopApiServer() {
    if (server) {
        server.close()
        server = null
        fileLibrary = null
        apiToken = null
    }
}

export function updateApiServerLibrary(library) {
    fileLibrary = library
}
