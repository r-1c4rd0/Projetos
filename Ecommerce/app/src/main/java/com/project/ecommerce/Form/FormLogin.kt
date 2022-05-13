package com.project.ecommerce.Form

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.view.View
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.snackbar.Snackbar
import com.google.firebase.auth.FirebaseAuth
import com.project.ecommerce.Model.DataStore
import com.project.ecommerce.R
import com.project.ecommerce.TelaPrincipal
import kotlinx.android.synthetic.main.activity_form_login.*


class FormLogin : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_form_login)
       VerificarUsuarioLogado()
        supportActionBar!!.hide()

        text_cadastrar.setOnClickListener{
            val intent = Intent(this, FormCadastro::class.java)
            startActivity(intent)

        }
        val preferences =
            getSharedPreferences(getString(R.string.filename_clocks), Context.MODE_PRIVATE)
        val remember = preferences.getBoolean(getString(R.string.pref_remember), false)
        val login = preferences.getString(getString(R.string.pref_login), null)
        val password = preferences.getString(getString(R.string.pref_password), null)
        if (remember) {
            swiRemember.isChecked = remember
            EmailAddress.setText(login)
            Password.setText(password)
        }
    }



    fun btnSigninOnClick(view: View) {
        val login = EmailAddress.text.toString()
        val password = Password.text.toString()
        if (login.equals(DataStore.login) && password.equals(DataStore.password)) {
            val preferences =
                getSharedPreferences(getString(R.string.filename_clocks), Context.MODE_PRIVATE)
            if (swiRemember.isChecked) {
                preferences.edit().apply() {
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
            AutenticarUsuario()

        }else{
            val dialog = AlertDialog.Builder(this)
            dialog.setTitle("Erro")
            dialog.setMessage("Login ou senha não confere!!")
            dialog.setPositiveButton(android.R.string.ok, null)
            dialog.show()
        }
    }
    private fun AutenticarUsuario(){
        val login = EmailAddress.text.toString()
        val password = Password.text.toString()
        if(login.isEmpty() || password.isEmpty()){
            var snackbar = Snackbar.make(layout_login,"Coloque um e-mail e uma senha", Snackbar.LENGTH_INDEFINITE).setBackgroundTint(
                Color.WHITE).setTextColor(Color.BLACK)
                .setAction("OK", View.OnClickListener {

                })
            snackbar.show()
        }else{
            FirebaseAuth.getInstance().signInWithEmailAndPassword(login, password).addOnCompleteListener {
                if(it.isSuccessful){
                    framel.visibility = View.VISIBLE
                    Handler().postDelayed({AbrirTelaPrincipal()}, 3000)

                }
            }.addOnFailureListener{
                var snackbar = Snackbar.make(layout_login,"Erro ao logar usuário", Snackbar.LENGTH_INDEFINITE).setBackgroundTint(
                    Color.WHITE).setTextColor(Color.BLACK)
                    .setAction("OK", View.OnClickListener {

                    })
                snackbar.show()

            }
        }

    }
    private fun VerificarUsuarioLogado(){
        val usuarioAtual = FirebaseAuth.getInstance().currentUser
        if(usuarioAtual != null){
            AbrirTelaPrincipal()
        }
    }
    private fun AbrirTelaPrincipal(){
        var intent = Intent(this, TelaPrincipal::class.java)
        startActivity(intent)
        finish()
    }
}
