package com.project.ecommerce

import android.content.Intent
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import com.heinrichreimersoftware.materialintro.app.IntroActivity
import com.heinrichreimersoftware.materialintro.slide.SimpleSlide
import com.project.ecommerce.Form.FormLogin

class Slides : IntroActivity(){
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        //setContentView(R.layout.activity_slides)
        isButtonBackVisible =false
        isButtonNextVisible = false


        addSlide(
            SimpleSlide.Builder()
                .background(R.color.purple_700)
                .backgroundDark(R.color.white)
                .image(R.drawable.drawer)
                .title("Loja Online")
                .description("Entre e confira as promoções que preparamos  para você!")
                .build()
        )
        addSlide(
            SimpleSlide.Builder()
                .background(R.color.purple_200)
                .title("Crie uma conta Grátis")
                .canGoBackward(false)
                .description("Cadastre-se agora mesmo! E venha conhecer os nossos produtos.")
                .build()
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        var intent = Intent(this, FormLogin::class.java)
        startActivity(intent)
        finish()
    }

}