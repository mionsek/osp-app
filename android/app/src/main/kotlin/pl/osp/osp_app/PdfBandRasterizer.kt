package pl.osp.osp_app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.File

/**
 * Strona PDF do druku na drukarce Bluetooth — w odcieniach szarości,
 * jeden bajt na punkt drukarki.
 *
 * Każdy punkt to średnia z bloku `supersample × supersample` pikseli, jak
 * w wersjach do 1.9.3: cienkie kreski i drobny tekst wychodzą wtedy pełne,
 * a nie przerywane. Wtedy jednak cała strona renderowała się naraz
 * w podwójnej gęstości (63 MB) i wtyczka `printing` przekazywała ją dalej
 * w całości — telefon zamykał aplikację z braku pamięci (fix/054). Dlatego
 * od fix/054 strona szła w rozdzielczości drukarki, a druk wyszedł słabszy.
 *
 * Tu strona renderuje się w poziomych pasach po [bandRows] punktów: w pamięci
 * jest naraz tylko jeden pas (kilka MB) i gotowy obraz w szarości (ok. 4 MB
 * na A4), a do Darta idzie wyłącznie ten drugi.
 */
object PdfBandRasterizer {
    class GrayPage(val width: Int, val height: Int, val gray: ByteArray)

    fun pageCount(pdf: File): Int = withRenderer(pdf) { it.pageCount }

    fun renderPage(pdf: File, index: Int, dpi: Double, supersample: Int, bandRows: Int): GrayPage =
        withRenderer(pdf) { renderer ->
            val page = renderer.openPage(index)
            try {
                render(page, dpi, supersample.coerceAtLeast(1), bandRows.coerceAtLeast(1))
            } finally {
                page.close()
            }
        }

    private fun <T> withRenderer(pdf: File, block: (PdfRenderer) -> T): T {
        val fd = ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY)
        // PdfRenderer zamyka deskryptor razem ze sobą.
        val renderer = try {
            PdfRenderer(fd)
        } catch (e: Exception) {
            fd.close()
            throw e
        }
        try {
            return block(renderer)
        } finally {
            renderer.close()
        }
    }

    private fun render(page: PdfRenderer.Page, dpi: Double, ss: Int, bandRows: Int): GrayPage {
        val scale = dpi / 72.0
        // Wymiary jak w Printing.raster (obcięcie do pełnych punktów) —
        // krótszy bok A4 to dokładnie szerokość drukarki.
        val width = (page.width * scale).toInt()
        val height = (page.height * scale).toInt()
        val gray = ByteArray(width * height)

        val bandWidth = width * ss
        val bandHeight = bandRows * ss
        val band = Bitmap.createBitmap(bandWidth, bandHeight, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(bandWidth * bandHeight)
        val matrix = Matrix()
        val samples = ss * ss
        try {
            var top = 0
            while (top < height) {
                val rows = minOf(bandRows, height - top)
                // Bez tego tło zostaje przezroczyste, a pas — z poprzedniego.
                band.eraseColor(Color.WHITE)
                matrix.setScale((scale * ss).toFloat(), (scale * ss).toFloat())
                matrix.postTranslate(0f, -(top * ss).toFloat())
                page.render(band, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                band.getPixels(pixels, 0, bandWidth, 0, 0, bandWidth, rows * ss)

                for (y in 0 until rows) {
                    val out = (top + y) * width
                    for (x in 0 until width) {
                        var sum = 0
                        for (sy in 0 until ss) {
                            var i = (y * ss + sy) * bandWidth + x * ss
                            for (sx in 0 until ss) {
                                val c = pixels[i++]
                                sum += (((c shr 16) and 0xFF) * 299 +
                                    ((c shr 8) and 0xFF) * 587 +
                                    (c and 0xFF) * 114) / 1000
                            }
                        }
                        gray[out + x] = (sum / samples).toByte()
                    }
                }
                top += rows
            }
        } finally {
            band.recycle()
        }
        return GrayPage(width, height, gray)
    }
}
