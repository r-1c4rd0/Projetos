package com.projetfull.startuspet.Controller

import android.content.Context
import android.content.Intent
import android.icu.text.DateTimePatternGenerator.PatternInfo.OK
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AlertDialog
import com.projetfull.startuspet.R
import kotlinx.android.synthetic.main.activity_form_login.*

class FormLogin : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        //DataStore.setContext(this)
        setContentView(R.layout.activity_form_login)
        supportActionBar!!.hide()
        val preferences =
            getSharedPreferences(getString(R.string.filename_animais), Context.MODE_PRIVATE)
        val remember = preferences.getBoolean(getString(R.string.pref_remember), false)
        val login = preferences.getString(getString(R.string.pref_login), null)
        val password = preferences.getString(getString(R.string.pref_password), null)
        if (remember){
            swiRemember.isChecked = remember
            EmailAddress.setText(login)
            Password.setText(password)
        }

        val textoCadastrar = text_cadastrar
        textoCadastrar.setOnClickListener {
            AbrirTelaDeCadastro()
        }
    }

    private fun AbrirTelaDeCadastro() {
        var intent = Intent(this, ManagerCadastroActivity::class.java)
        startActivity(intent)
        finish()

    }

    fun btnSigninOnClick(view: View) {
        val login = EmailAddress.text.toString()
        val password = Password.text.toString()
        if (login.equals(DataStore.login) && password.equals(DataStore.password)) {

            val preferences =
                getSharedPreferences(getString(R.string.filename_animais), Context.MODE_PRIVATE)

            if (swiRemember.isChecked) { preferences.edit().apply() {
                putBoolean(getString(R.string.pref_remember), swiRemember.isChecked)
                putString(getString(R.string.pref_login), EmailAddress.text.toString())
                putString(getString(R.string.pref_password), Password.text.toString())
                commit()

                }
            } else {
                preferences.edit().apply() {
                    putBoolean(getString(R.string.pref_remember), swiRemember.isChecked)
                    putString(getString(R.string.pref_login), null)
                    putString(getString(R.string.pref_password), null)
                    commit()
                }

            }

            val intent = Intent(this, ManagerCadastroActivity::class.java)
            startActivity(intent)
            finish()
        } else {
            val dialog = AlertDialog.Builder(this)
            dialog.setTitle("Erro")
            dialog.setMessage("Login ou senha n??o confere!!")
            dialog.setPositiveButton(android.R.string.ok, null)
            dialog.show()

        }
    }
}