package org.mewx.wenku8_flutter

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class Wenku8UrlPolicyTest {
    @Test
    fun acceptsOnlyOfficialHttpsPages() {
        assertTrue(Wenku8UrlPolicy.isOfficialPage("https://www.wenku8.net/index.php"))
        assertTrue(Wenku8UrlPolicy.isOfficialPage("https://wenku8.net/modules/article/toplist.php?sort=allvisit"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("http://www.wenku8.net/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://wenku8.net.evil.example/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://user@www.wenku8.net/index.php"))
        assertFalse(Wenku8UrlPolicy.isOfficialPage("https://www.wenku8.net:444/index.php"))
    }

    @Test
    fun acceptsOnlyKnownImageHostsAndImagePaths() {
        assertTrue(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/4/4265/4265s.jpg"))
        assertTrue(Wenku8UrlPolicy.isAllowedImage("https://pic.wenku8.cn/pictures/4/4265/illustration.webp"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://evil.example/image/4/4265/4265s.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/4/4265/4265s.jpg?redirect=evil"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("https://img.wenku8.com/image/../secret.jpg"))
        assertFalse(Wenku8UrlPolicy.isAllowedImage("http://img.wenku8.com/image/4/4265/4265s.jpg"))
    }
}
