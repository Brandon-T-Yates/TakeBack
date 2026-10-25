package com.tyleryates.takeback

import android.app.Activity
import android.app.AlertDialog
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.util.LruCache
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.ImageView
import android.widget.ListView
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Picks the 1–50 launchable apps that stay available. Results are saved to [AndroidAllowedAppsStore]. */
class AllowedAppsActivity : Activity() {
    private lateinit var store: AndroidAllowedAppsStore
    private lateinit var list: ListView
    private lateinit var progress: ProgressBar
    private lateinit var empty: TextView
    private lateinit var count: TextView
    private lateinit var save: Button
    private val adapter = AppsAdapter()
    private val selected = LinkedHashSet<String>()
    private val icons = LruCache<String, Drawable>(120)
    private val main = Handler(Looper.getMainLooper())
    private lateinit var executor: ExecutorService
    private var apps: List<LaunchableApp> = emptyList()
    private var visible: List<LaunchableApp> = emptyList()
    private var query = ""
    private var loaded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_allowed_apps)
        setResult(RESULT_CANCELED)
        executor = Executors.newFixedThreadPool(2)
        store = AndroidAllowedAppsStore(this)
        selected.addAll(savedInstanceState?.getStringArrayList(STATE_SELECTED) ?: store.packages)
        query = savedInstanceState?.getString(STATE_QUERY).orEmpty()

        applySystemBarInsets(findViewById(R.id.allowed_apps_root))
        list = findViewById(R.id.allowed_apps_list)
        progress = findViewById(R.id.allowed_apps_progress)
        empty = findViewById(R.id.allowed_apps_empty)
        count = findViewById(R.id.allowed_apps_count)
        save = findViewById(R.id.allowed_apps_save)
        list.adapter = adapter
        list.setOnItemClickListener { _, _, position, _ -> toggle(visible[position].packageName) }

        findViewById<EditText>(R.id.allowed_apps_search).apply {
            setText(query)
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: Editable?) {
                    query = s?.toString().orEmpty()
                    applyFilter()
                }
            })
        }
        save.setOnClickListener { saveSelection() }
        findViewById<Button>(R.id.allowed_apps_cancel).setOnClickListener { finish() }
        findViewById<Button>(R.id.allowed_apps_clear).apply {
            visibility = if (store.hasSavedSelection) View.VISIBLE else View.GONE
            setOnClickListener { confirmClear() }
        }
        render()
        load()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putStringArrayList(STATE_SELECTED, ArrayList(selected))
        outState.putString(STATE_QUERY, query)
    }

    override fun onDestroy() {
        executor.shutdownNow()
        main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun load() {
        executor.execute {
            val result = LaunchableApps.list(applicationContext)
            main.post {
                if (isDestroyed) return@post
                apps = result
                val installed = result.mapTo(HashSet()) { it.packageName }
                selected.retainAll(installed)
                loaded = true
                applyFilter()
            }
        }
    }

    private fun applyFilter() {
        val needle = query.trim()
        visible = if (needle.isEmpty()) apps else apps.filter {
            it.label.contains(needle, ignoreCase = true) ||
                it.packageName.contains(needle, ignoreCase = true)
        }
        render()
    }

    private fun toggle(packageName: String) {
        if (!selected.remove(packageName)) {
            if (selected.size >= AndroidAllowedAppsStore.MAX_APPS) {
                Toast.makeText(this, R.string.allowed_apps_limit, Toast.LENGTH_SHORT).show()
                return
            }
            selected.add(packageName)
        }
        render()
    }

    private fun render() {
        progress.visibility = if (loaded) View.GONE else View.VISIBLE
        empty.visibility = if (loaded && visible.isEmpty()) View.VISIBLE else View.GONE
        count.text = if (selected.isEmpty()) {
            getString(R.string.allowed_apps_count_empty)
        } else {
            getString(R.string.allowed_apps_count, selected.size)
        }
        save.isEnabled = loaded &&
            selected.size in AndroidAllowedAppsStore.MIN_APPS..AndroidAllowedAppsStore.MAX_APPS
        adapter.notifyDataSetChanged()
    }

    private fun saveSelection() {
        if (selected.size !in AndroidAllowedAppsStore.MIN_APPS..AndroidAllowedAppsStore.MAX_APPS) return
        store.save(selected)
        setResult(RESULT_OK)
        finish()
    }

    private fun confirmClear() {
        AlertDialog.Builder(this)
            .setTitle(R.string.allowed_apps_clear_title)
            .setMessage(R.string.allowed_apps_clear_message)
            .setPositiveButton(R.string.allowed_apps_clear_confirm) { _, _ ->
                store.clear()
                setResult(RESULT_OK)
                finish()
            }
            .setNegativeButton(R.string.allowed_apps_cancel, null)
            .show()
    }

    private fun applySystemBarInsets(root: View) {
        val left = root.paddingLeft
        val top = root.paddingTop
        val right = root.paddingRight
        val bottom = root.paddingBottom
        root.setOnApplyWindowInsetsListener { view, insets ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
                view.setPadding(left + bars.left, top + bars.top, right + bars.right, bottom + bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(
                    left + insets.systemWindowInsetLeft,
                    top + insets.systemWindowInsetTop,
                    right + insets.systemWindowInsetRight,
                    bottom + insets.systemWindowInsetBottom,
                )
            }
            insets
        }
    }

    private fun loadIcon(packageName: String, target: ImageView) {
        icons.get(packageName)?.let {
            target.setImageDrawable(it)
            return
        }
        target.setImageDrawable(null)
        executor.execute {
            val icon = LaunchableApps.icon(applicationContext, packageName) ?: return@execute
            main.post {
                icons.put(packageName, icon)
                if (target.tag == packageName) target.setImageDrawable(icon)
            }
        }
    }

    private inner class AppsAdapter : BaseAdapter() {
        override fun getCount() = visible.size
        override fun getItem(position: Int) = visible[position]
        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val row = convertView ?: layoutInflater.inflate(R.layout.item_allowed_app, parent, false).also {
                it.accessibilityDelegate = CheckableRowDelegate()
            }
            val app = visible[position]
            val icon = row.findViewById<ImageView>(R.id.allowed_app_icon)
            row.tag = app.packageName
            icon.tag = app.packageName
            row.findViewById<TextView>(R.id.allowed_app_label).text = app.label
            row.findViewById<TextView>(R.id.allowed_app_package).text = app.packageName
            row.findViewById<CheckBox>(R.id.allowed_app_check).isChecked = app.packageName in selected
            loadIcon(app.packageName, icon)
            return row
        }
    }

    private inner class CheckableRowDelegate : View.AccessibilityDelegate() {
        override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) {
            super.onInitializeAccessibilityNodeInfo(host, info)
            info.className = CheckBox::class.java.name
            info.isCheckable = true
            info.isChecked = (host.tag as? String)?.let { it in selected } == true
        }
    }

    companion object {
        private const val STATE_SELECTED = "selected"
        private const val STATE_QUERY = "query"
    }
}
