package com.comercio.petsphere

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.comercio.petsphere.controller.MainActivity

import com.comercio.petsphere.model.Cliente

class LoginActivity : AppCompatActivity() {

    private lateinit var binding: ActivityLoginBinding
    private lateinit var cliente: Cliente

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

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

        // Configuração de preferências
        val preferences = getSharedPreferences(getString(R.string.file_preferences), Context.MODE_PRIVATE)
        val remember = preferences.getBoolean(getString(R.string.pref_remember), false)
        val login = preferences.getString(getString(R.string.pref_login), null)
        val password = preferences.getString(getString(R.string.pref_password), null)

        if (remember) {
            binding.swiRemember.isChecked = remember
            binding.txtLogin.setText(login)
            binding.txtPassword.setText(password)
        }

        binding.btnSignin.setOnClickListener { btnSigninOnClick(it) }
    }

    private fun btnSigninOnClick(view: View) {
        val login = binding.txtLogin.text.toString()
        val password = binding.txtPassword.text.toString()

        // Verificação das credenciais
        if (login == cliente.login && password == cliente.senha) {
            val preferences = getSharedPreferences(getString(R.string.file_preferences), Context.MODE_PRIVATE)

            if (binding.swiRemember.isChecked) {
                preferences.edit().apply {
                    putBoolean(getString(R.string.pref_remember), binding.swiRemember.isChecked)
                    putString(getString(R.string.pref_login), binding.txtLogin.text.toString())
                    putString(getString(R.string.pref_password), binding.txtPassword.text.toString())
                    apply()
                }
            } else {
                preferences.edit().apply {
                    putBoolean(getString(R.string.pref_remember), binding.swiRemember.isChecked)
                    putString(getString(R.string.pref_login), null)
                    putString(getString(R.string.pref_password), null)
                    apply()
                }
            }

            // Iniciar a MainActivity
            val intent = Intent(this, MainActivity::class.java)
            startActivity(intent)
            finish()
        } else {
            // Exibir mensagem de erro
            val dialog = AlertDialog.Builder(this)
            dialog.setTitle("Erro")
            dialog.setMessage("Login ou senha não conferem!")
            dialog.setPositiveButton(android.R.string.ok, null)
            dialog.show()
        }
    }
}
