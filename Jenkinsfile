//TODO: Work In Progress - Jenkinsfile for building the amis.

node {
    currentBuild.displayName = "#${env.BUILD_NUMBER}: ${Component}-${ImageConfiguration} "


stage ('Checkout') {
    
    node {
        echo "Initialization of ${ImageConfiguration} ${Component} Started"
        
        // Cleanup local checkout
        sh "rm -rf *"
        sh "rm -rf .git"

        // Clone from git
        checkout scm

        // Checkout specific local branch
        checkout([$class: 'GitSCM', branches: [[name: '*/master']],
            extensions: [[$class: 'CleanCheckout'],[$class: 'LocalBranch', localBranch: "master"]]])

        echo 'Initialization Complete'
    }
    
}

stage ('Tagging') {

        echo "Tagging of ${Component}-${ImageConfiguration}-${env.BUILD_NUMBER} Started"

        // Add tag to repository for mapping ami and build back to source code.
        sh "git tag -a ${Component}-${ImageConfiguration}-${env.BUILD_NUMBER} -m \"Used to build ${Component}-${ImageConfiguration}-${env.BUILD_NUMBER}\""

        echo 'Tagging Complete'

    }

stage ('Configuration') {
    
    node {
        echo "Configuration of ${ImageConfiguration} ${Component} Started"

        echo "PATH=${env.PATH}"
        env.PATH = "/usr/local/bin:${env.PATH}"
        echo "PATH=${env.PATH}"

        echo 'Configuration Complete'
    }
    
}

//TODO: Should not need this stage. dependencies should be included in the packer-aem release zip.

stage ('Dependencies') {
    
    node {
        echo "Dependencies of ${ImageConfiguration} ${Component} Started"

        sh 'make clean deps'

        echo 'Dependencies Complete'
    }
}

stage ('Build') {
    
    node {
        echo "Build of ${ImageConfiguration} ${Component} Started"

        // If base image then update with AMI base id from Jenkins parameter
        if ("${Component}" == "base") {
            sh "jq \'.base_ami_source_ami = \"$BaseAMIid\"\' ./conf/aws/${ImageConfiguration}.json > tmp.json"
            sh "cat tmp.json > ./conf/aws/${ImageConfiguration}.json"
            sh "rm tmp.json"
        }

        if ("${Component}" == "publish" || "${Component}" == "author") {

            retry(5){
                sh "make ${Component} version=${env.BUILD_NUMBER} var_file=./conf/aws/${ImageConfiguration}.json"
            }

        } else {

            sh "make ${Component} version=${env.BUILD_NUMBER} var_file=./conf/aws/${ImageConfiguration}.json"

        }

        echo 'Build Complete'
    }
    
}

stage ('Commit') {
    
    node {
        echo "Commit of ${ImageConfiguration} ${Component} Started"

        if ("${Component}" == "base" || "${Component}" == "java" || "${Component}" == "httpd" ) {

            dir('.'){

                def sourceList

                switch ("${Component}") {

                    case 'base':

                        sourceList = "java and httpd"

                        break

                    case 'java':

                        sourceList = "author and publish"

                        break

                    case 'httpd':

                        sourceList = "dispatcher"

                        break

                    default:

                        sourceList = "unknown"

                        break

                }

                //TODO: need to handle concurrent pushes to the repo. git push or pull rebase or push etc....

                try {
                  withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: "${credentialid}", usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']]) {
                      sh("git config credential.username ${env.GIT_USERNAME}")
                      sh("git config credential.helper '!echo password=\$GIT_PASSWORD; echo'")
                      sh("git add .")
                      sh("git commit -m \"Update ${sourceList} Source AMI ID - ${env.BUILD_URL}\"")
                      sh("git pull --rebase origin master")
                      sh("GIT_ASKPASS=true git push origin master")
                  }
                } finally {
                      sh("git config --unset credential.username")
                      sh("git config --unset credential.helper")
                }

            }

        }
        
        echo 'Commit Complete'
    }

}

}
