package com.project.ecommerce

import android.content.Intent
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import androidx.appcompat.app.ActionBarDrawerToggle
import com.google.android.material.navigation.NavigationView
import androidx.navigation.ui.AppBarConfiguration
import androidx.drawerlayout.widget.DrawerLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.Toolbar
import androidx.core.view.GravityCompat
import com.google.firebase.auth.FirebaseAuth
import com.project.ecommerce.Form.FormLogin
import com.project.ecommerce.Fragments.CadastroProdutos
import com.project.ecommerce.Fragments.Produtos

class TelaPrincipal : AppCompatActivity(), NavigationView.OnNavigationItemSelectedListener {

    private lateinit var appBarConfiguration: AppBarConfiguration

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_tela_principal)
        val toolbar: Toolbar = findViewById(R.id.toolbar)
        setSupportActionBar(toolbar)
        telaProdutos()



        val drawerLayout: DrawerLayout = findViewById(R.id.drawer_layout)
        val navView: NavigationView = findViewById(R.id.nav_view)
        val toggle = ActionBarDrawerToggle(
                this, drawerLayout, toolbar, R.string.navigation_drawer_open, R.string.navigation_drawer_close)
        drawerLayout.addDrawerListener(toggle)
        toggle.syncState()
        navView.setNavigationItemSelectedListener(this)
    }

    override fun onNavigationItemSelected(item: MenuItem): Boolean {
        val id = item.itemId
        if (id == R.id.nav_produto){
            telaProdutos()
        }else if (id == R.id.nav_cadastrar_produto){
            var intent = Intent(this, CadastroProdutos::class.java)
            startActivity(intent)

        }else if(id == R.id.nav_contato){
            sendEmail()

        }
        val drawer = findViewById<DrawerLayout>(R.id.drawer_layout)
        drawer.closeDrawer(GravityCompat.START)
        return true
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        // Inflate the menu; this adds items to the action bar if it is present.
        menuInflater.inflate(R.menu.tela_principal, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        val id = item.itemId
        if (id == R.id.action_settings)
            FirebaseAuth.getInstance().signOut()
        VoltarParaFormLogin()
        return super.onOptionsItemSelected(item)
    }



    private fun VoltarParaFormLogin() {
        var intent = Intent(this, FormLogin::class.java)
        startActivity(intent)
        finish()
    }
    private fun telaProdutos(){
        val produtosFrament = Produtos()
        val fragment = supportFragmentManager.beginTransaction()
        fragment.replace(R.id.frameContainer, produtosFrament)
        fragment.commit()
    }

    private fun sendEmail(){
        val PACKAGEM_GOOGLEMAIL = "com.google.android.gm"
        val email = Intent(Intent.ACTION_SEND)
        email.putExtra(Intent.EXTRA_EMAIL, arrayOf("")) //send a e-mail
        email.putExtra(Intent.EXTRA_SUBJECT, "")
        email.putExtra(Intent.EXTRA_TEXT, "")    // send body text e-mail

        email.type = "messafe/rec822"
        email.setPackage(PACKAGEM_GOOGLEMAIL)
        startActivity(Intent.createChooser(email, "Escolha o app de e-mail"))

    }
}