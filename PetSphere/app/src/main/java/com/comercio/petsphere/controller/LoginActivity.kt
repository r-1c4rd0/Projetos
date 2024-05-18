import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.appcompat.app.AlertDialog
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.*
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.comercio.petsphere.R
import com.comercio.petsphere.controller.MainActivity
import com.comercio.petsphere.model.Cliente

class LoginActivity : ComponentActivity() {
    private lateinit var cliente: Cliente

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configuração inicial do cliente para teste
        cliente = Cliente(
            nome = "John Doe",
            email = "johndoe@example.com",
            telefone = "123456789",
            endereco = "123 Street",
            animais = mutableListOf(),
            login = "user",
            senha = "password"
        )

        setContent {
            LoginScreen(cliente)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(cliente: Cliente) {
    val context = LocalContext.current
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var rememberMe by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        TextField(
            value = username,
            onValueChange = { username = it },
            label = { Text("Login") },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp)
        )

        TextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Senha") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp)
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(vertical = 8.dp)
        ) {
            Text("Lembrar de mim")
            Spacer(modifier = Modifier.width(8.dp))
            Switch(
                checked = rememberMe,
                onCheckedChange = { rememberMe = it }
            )
        }

        Button(
            onClick = {
                // Verificação das credenciais
                if (username == cliente.login && password == cliente.senha) {
                    val preferences = context.getSharedPreferences(
                        context.getString(R.string.file_preferences),
                        Context.MODE_PRIVATE
                    )

                    if (rememberMe) {
                        preferences.edit().apply {
                            putBoolean(context.getString(R.string.pref_remember), rememberMe)
                            putString(context.getString(R.string.pref_login), username)
                            putString(context.getString(R.string.pref_password), password)
                            apply()
                        }
                    } else {
                        preferences.edit().apply {
                            putBoolean(context.getString(R.string.pref_remember), rememberMe)
                            putString(context.getString(R.string.pref_login), null)
                            putString(context.getString(R.string.pref_password), null)
                            apply()
                        }
                    }

                    // Iniciar a MainActivity
                    val intent = Intent(context, MainActivity::class.java)
                    context.startActivity(intent)
                    (context as LoginActivity).finish()
                } else {
                    // Exibir mensagem de erro
                    AlertDialog.Builder(context)
                        .setTitle("Erro")
                        .setMessage("Login ou senha não conferem!")
                        .setPositiveButton(android.R.string.ok, null)
                        .show()
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 16.dp)
        ) {
            Text("Entrar")
        }
    }
}

@Preview(showBackground = true)
@Composable
fun PreviewLoginScreen() {
    LoginScreen(
        Cliente(
            nome = "John Doe",
            email = "johndoe@example.com",
            telefone = "123456789",
            endereco = "123 Street",
            animais = mutableListOf(),
            login = "user",
            senha = "password"
        )
    )
}
