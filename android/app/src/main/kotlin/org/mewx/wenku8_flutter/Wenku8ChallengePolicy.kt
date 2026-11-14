package org.mewx.wenku8_flutter

/** Identify an actual challenge, not a normal page containing a Cloudflare script. */
internal object Wenku8ChallengePolicy {
    private val challengeTitle = Regex(
        """<title\b[^>]*>\s*(?:just a moment(?:\.{1,3}|…)?|attention required!?\s*(?:\|\s*cloudflare)?|checking your browser(?:\.{1,3}|…)?)\s*</title\s*>""",
        RegexOption.IGNORE_CASE,
    )
    private val challengeForm = Regex(
        """<form\b[^>]*\bid\s*=\s*["'](?:challenge-form|challenge-stage)["']""",
        RegexOption.IGNORE_CASE,
    )
    private val challengeScript = Regex(
        """(?:\b_cf_chl_opt\s*=|/cdn-cgi/challenge-platform/|\bcf-chl-)""",
        RegexOption.IGNORE_CASE,
    )

    fun isChallenge(body: String, mitigatedHeader: String?): Boolean {
        if (mitigatedHeader?.trim()?.equals("challenge", ignoreCase = true) == true) return true
        if (challengeTitle.containsMatchIn(body)) return true
        return challengeForm.containsMatchIn(body) && challengeScript.containsMatchIn(body)
    }
}
