package com.sanjaya.jigu

object WidgetRelativeTime {
    fun label(timestamp: Long, now: Long = System.currentTimeMillis()): String {
        if (timestamp <= 0L) return "No location shared yet"
        val seconds = ((now - timestamp) / 1000).coerceAtLeast(0)
        if (seconds < 60) return "Live · just now"
        val minutes = seconds / 60
        if (minutes < 60) return "$minutes min ago"
        val hours = minutes / 60
        if (hours < 24) return "$hours ${if (hours == 1L) "hour" else "hours"} ago"
        val days = hours / 24
        if (days < 7) return "$days ${if (days == 1L) "day" else "days"} ago"
        if (days < 30) { val weeks = days / 7; return "$weeks ${if (weeks == 1L) "week" else "weeks"} ago" }
        if (days < 365) { val months = days / 30; return "$months ${if (months == 1L) "month" else "months"} ago" }
        val years = days / 365
        return "$years ${if (years == 1L) "year" else "years"} ago"
    }
}
