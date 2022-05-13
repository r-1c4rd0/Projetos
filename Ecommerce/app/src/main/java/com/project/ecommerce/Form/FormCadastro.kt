package com.project.ecommerce.Form

import android.content.Intent
import android.graphics.Color
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.view.View
import android.widget.Toast
import com.google.android.material.snackbar.Snackbar
import com.google.android.material.snackbar.Snackbar.make
import com.google.firebase.auth.FirebaseAuth
import com.project.ecommerce.R
import kotlinx.android.synthetic.main.activity_form_cadastro.*

class FormCadastro : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_form_cadastro)
        supportActionBar!!.hide()
        bt_cadastrar.setOnClickListener {
            CadastrarUsuario()
        }
    }

    private fun CadastrarUsuario() {
        val email = EmailAddress.text.toString()
        val senha = Password.text.toString()

        if (email.isEmpty() || senha.isEmpty()) {
            var snackbar = Snackbar.make(layout_cadastro, "Coloque seu e-mail e sua senha!", Snackbar.LENGTH_INDEFINITE)
                .setBackgroundTint(Color.WHITE).setTextColor(Color.BLACK).setAction("OK", View.OnClickListener {

                })
            snackbar.show()
        }else{
            FirebaseAuth.getInstance().createUserWithEmailAndPassword(email,senha).addOnCompleteListener {
                if (it.isSuccessful){
                    var snackbar = Snackbar.make(layout_cadastro, "Cadastro realizado com sucesso!", Snackbar.LENGTH_INDEFINITE)
                        .setBackgroundTint(Color.WHITE).setTextColor(Color.BLACK).setAction("OK", View.OnClickListener {
                            voltarParaFormLogin()
                        })
                    snackbar.show()
                }

            }.addOnFailureListener {
                var snackbar = Snackbar.make(layout_cadastro, "Erro ao cadastrar o usuário!", Snackbar.LENGTH_INDEFINITE)
                    .setBackgroundTint(Color.WHITE).setTextColor(Color.BLACK).setAction("OK", View.OnClickListener {

                    })
                snackbar.show()
            }
        }
    }
    private fun voltarParaFormLogin(){
        var intent = Intent(this, FormLogin::class.java)
        startActivity(intent)
        finish()

    }
}