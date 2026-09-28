// Saving a file the admin site made (bolt 056): an export, or a template.

/** A file name from a lesson's title: letters (Ethiopic too) and digits,
 * everything else a single hyphen. */
export function fileName(title: string, suffix: string): string {
  const stem = title
    .trim()
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-+|-+$/g, '')
  return `${stem || 'lesson'}${suffix}`
}

export function saveFile(name: string, text: string, type: string): void {
  const url = URL.createObjectURL(new Blob([text], { type }))
  const link = document.createElement('a')
  link.href = url
  link.download = name
  document.body.append(link)
  link.click()
  link.remove()
  // After the click has been handled, or some browsers save nothing.
  setTimeout(() => URL.revokeObjectURL(url), 0)
}

/** A chosen file's text, read as UTF-8: bytes that aren't become U+FFFD,
 * which the CSV reader looks for. */
export function readText(file: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error ?? new Error('The file could not be read.'))
    reader.readAsText(file, 'utf-8')
  })
}

export const CSV_TYPE = 'text/csv;charset=utf-8'
export const JSON_TYPE = 'application/json'
