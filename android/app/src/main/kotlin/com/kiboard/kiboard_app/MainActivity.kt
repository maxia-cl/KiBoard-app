package com.kiboard.kiboard_app

import android.graphics.Rect
import android.os.Build
import android.view.View
import io.flutter.embedding.android.FlutterActivity

/**
 * The deck's page swipe runs edge to edge, and on gesture navigation both screen edges belong to
 * Android's back gesture. Without this, swiping back a page with a thumb near the edge is taken by
 * the system instead: the page half-moves, the drag is cancelled, and the user gets a back press
 * they did not ask for.
 *
 * [View.setSystemGestureExclusionRects] claims those strips for the app. Android caps what it will
 * honour at 200 dp per edge and reserves the right to ignore it entirely, so this is a strong hint
 * rather than a guarantee — which is why the deck also confirms before it lets a back press leave.
 *
 * Nothing to undo: the rects live on the content view and go with the activity.
 */
class MainActivity : FlutterActivity() {
    override fun onPostResume() {
        super.onPostResume()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val root = window.decorView.findViewById<View>(android.R.id.content) ?: return
        root.doOnLayoutEdges { width, height ->
            val edge = (24 * resources.displayMetrics.density).toInt()
            root.systemGestureExclusionRects = listOf(
                Rect(0, 0, edge, height),
                Rect(width - edge, 0, width, height),
            )
        }
    }
}

/** Runs [block] with the view's size, now if it already has one and on the next layout if not. */
private inline fun View.doOnLayoutEdges(crossinline block: (width: Int, height: Int) -> Unit) {
    if (width > 0 && height > 0) {
        block(width, height)
        return
    }
    addOnLayoutChangeListener(
        object : View.OnLayoutChangeListener {
            override fun onLayoutChange(
                v: View, l: Int, t: Int, r: Int, b: Int,
                ol: Int, ot: Int, or_: Int, ob: Int,
            ) {
                if (v.width <= 0 || v.height <= 0) return
                v.removeOnLayoutChangeListener(this)
                block(v.width, v.height)
            }
        },
    )
}
