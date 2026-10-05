// Reading and saving the curriculum workbook in the browser (intent 025).
// Kept apart from `model.ts` so tests can hand the model the real
// workbook, read with the Node build.

import readExcelFile from 'read-excel-file/browser'
import writeExcelFile from 'write-excel-file/browser'

import type { Sheet } from './model'

/** Every tab of a chosen `.xlsx` file. */
export async function readWorkbook(file: File): Promise<Sheet[]> {
  const sheets = await readExcelFile(file)
  return sheets.map((s) => ({ sheet: s.sheet, data: s.data as unknown[][] }))
}

/** Saves tabs as an `.xlsx` file, with the header row kept in view. */
export async function saveWorkbook(name: string, sheets: { sheet: string; data: (string | number | null)[][] }[]) {
  await writeExcelFile(
    sheets.map((s) => ({ sheet: s.sheet, data: s.data, stickyRowsCount: 1 })),
  ).toFile(name)
}
