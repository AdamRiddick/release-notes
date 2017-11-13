Welcome to the release-notes wiki!

# Getting Started
Release Notes is a VSTS extension which generates release notes based on the changes that have occurred from the build artifacts from the last release to the current release, base on successful deployment of the environment the task is placed within (unless overridden.)

> Unfortunately, the API doesn't currently support getting all changes to a release, without a previous release, meaning this extension requires a previous successful release on the specified stage in order to generate release notes. If there is no previous release, the task will not generate any output.

## Inputs
* Release Environment Name - The name of the release environment to check was successful releases when generating release notes. If not provided, this will default to the environment holding the release notes task.

* Personal Access Token - This token is generated against your account, and requires access to Release and Build. This is used to access API's and gather the required release information.

* Template - The template to use for generating messages, for example, to generate a list;
```html
<ul style="margin:0; padding:0;">{messages}<li style="margin:0 0 1em; list-style:disc inside; mso-special-
    format:bullet;">{message}</li>{messages}</ul>
```

* Template Message Variable - The tag within the template to replace with a changeset message. In the example template, this would be {message}.

* Template Messages Variable - The tag within the template used to define the section to loop per changeset message. In the example template, this would be {messages}.

* Output File Path - The file path, relative to the build agent, where the generated release note output should be saved. Release variables may be used in the path to dynamically create the release note files. The build agent must have write access to the location.

* Output Variable Name - The release variable name you have created to store the output of the generated release notes. This value can then be used in later release tasks, such as to email the content.

# Caveats
* The release message is the first line of the check-in or commit message - Any additional input will be stripped.
* If you release message does not end in a full stop, one is added.

# More Info
For more information, see [GitHub](https://github.com/AdamRiddick/release-notes/wiki/)

# Credits
<div>Icons made by <a href="https://www.flaticon.com/authors/anton-saputro" title="Anton Saputro">Anton Saputro</a> from <a href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a> is licensed by <a href="http://creativecommons.org/licenses/by/3.0/" title="Creative Commons BY 3.0" target="_blank">CC 3.0 BY</a></div>