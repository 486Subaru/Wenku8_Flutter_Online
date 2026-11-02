package org.mewx.wenku8_flutter

import java.net.URLEncoder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class LightNovelTokenParserTest {
    @Test
    fun parsesTokenCookieAmongOtherCookies() {
        val parsed = LightNovelTokenParser.fromCookieHeader(
            "PHPSESSID=abc; theme=dark; token={\"security_key\":\"signed:12345\"}; path=/",
        )
        assertNotNull(parsed)
        assertEquals("signed:12345", parsed?.securityKey)
        assertEquals("12345", parsed?.uid)
    }

    @Test
    fun decodesPercentEncodedTokenWithoutConvertingPlusToSpace() {
        val token = "{\"security_key\":\"abc+def:24680\"}"
        val encoded = URLEncoder.encode(token, "UTF-8")
        val parsed = LightNovelTokenParser.parseTokenValue(encoded)
        assertNotNull(parsed)
        assertEquals("abc+def:24680", parsed?.securityKey)
        assertEquals("24680", parsed?.uid)
    }

    @Test
    fun rejectsMissingOrMalformedTokenCredentials() {
        assertNull(LightNovelTokenParser.fromCookieHeader("PHPSESSID=abc; theme=dark"))
        assertNull(LightNovelTokenParser.parseTokenValue("{\"security_key\":\"missing-uid\"}"))
        assertNull(LightNovelTokenParser.parseTokenValue("not-a-token"))
    }
}
