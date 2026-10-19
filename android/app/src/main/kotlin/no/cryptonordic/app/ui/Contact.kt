package no.cryptonordic.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import no.cryptonordic.app.Api
import no.cryptonordic.app.Lang

/**
 * Publisher contact details. The title is the localized "Contact us"
 * (Play's News and magazines policy: a clearly labeled contact section).
 * [onBack] is set on TV, where this screen covers the information page.
 */
@Composable
fun ContactScreen(large: Boolean, onBack: (() -> Unit)? = null) {
    val ctx = LocalContext.current
    val emailFocus = remember { FocusRequester() }
    val title = if (large) 40.sp else 32.sp
    val pad = if (large) 28.dp else 16.dp

    LaunchedEffect(large) {
        if (large) runCatching { emailFocus.requestFocus() }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(pad),
        verticalArrangement = Arrangement.spacedBy(if (large) 18.dp else 14.dp),
    ) {
        Text(
            Lang.tr("Contact us"),
            color = NL.textPrimary,
            fontSize = title,
            fontWeight = FontWeight.Bold,
            fontFamily = NL.serif,
        )
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(NL.panel).padding(if (large) 20.dp else 16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(Lang.tr("Publisher"), color = NL.textSecondary, fontSize = if (large) 16.sp else 13.sp, fontWeight = FontWeight.SemiBold)
            Text(Api.PUBLISHER, color = NL.textPrimary, fontSize = if (large) 32.sp else 24.sp, fontWeight = FontWeight.Bold, fontFamily = NL.serif)
            Text(Api.PUBLISHER_COMPANY, color = NL.textPrimary, fontSize = if (large) 22.sp else 17.sp, fontWeight = FontWeight.SemiBold)
            Text(Lang.tr("Oslo, Norway"), color = NL.textSecondary, fontSize = if (large) 20.sp else 16.sp)
        }
        ContactLink(Lang.tr("Email"), Api.CONTACT_EMAIL, large, emailFocus) { open(ctx, Api.CONTACT_MAILTO) }
        ContactLink(Lang.tr("Website"), Api.WEBSITE, large) { open(ctx, Api.WEBSITE) }
        ContactLink(Lang.tr("Contact page"), Api.CONTACT_PAGE, large) { open(ctx, Api.CONTACT_PAGE) }
        if (onBack != null) {
            ContactLink(Lang.tr("Done"), "", large, emphasize = true, onClick = onBack)
        }
    }
}

@Composable
private fun ContactLink(
    label: String,
    value: String,
    large: Boolean,
    focus: FocusRequester? = null,
    emphasize: Boolean = false,
    onClick: () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier
            .fillMaxWidth()
            .then(if (focus != null) Modifier.focusRequester(focus) else Modifier)
            .onFocusChanged { focused = it.isFocused }
            .clip(shape)
            .background(if (focused) NL.raised else NL.panel)
            .border(if (focused && large) 3.dp else 0.dp, NL.accent, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(if (large) 18.dp else 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                label,
                color = if (emphasize) NL.textPrimary else NL.accent,
                fontSize = if (large) 18.sp else 13.sp,
                fontWeight = FontWeight.Bold,
            )
            if (value.isNotEmpty()) {
                Text(value, color = NL.textPrimary, fontSize = if (large) 22.sp else 17.sp)
            }
        }
        if (large && value.startsWith("https://")) QrCode(value, 88.dp)
    }
}

private fun open(ctx: android.content.Context, uri: String) {
    val parsed = Uri.parse(uri)
    val intent = if (uri.startsWith("mailto:")) Intent(Intent.ACTION_SENDTO, parsed) else Intent(Intent.ACTION_VIEW, parsed)
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    runCatching { ctx.startActivity(intent) }
}
