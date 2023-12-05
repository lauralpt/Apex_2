import { LightningElement, wire } from 'lwc';
import performNightlyIntegration from '@salesforce/apex/UclNightlyIntegrationController.performNightlyIntegration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NightlyServiceComponent extends LightningElement {
    @wire(performNightlyIntegration) integrationResult;

    handleInvokeIntegration() {
        performNightlyIntegration()
            .then(result => {
                // Mostrar un toast con el resultado exitoso
                const event = new ShowToastEvent({
                    title: 'Operación Exitosa',
                    message: `Integración nocturna realizada con éxito.`,
                    variant: 'success',
                });
                this.dispatchEvent(event);
            })
            .catch(error => {
                // Mostrar un toast con el mensaje de error
                const event = new ShowToastEvent({
                    title: 'Error',
                    message: `Error al ejecutar la integración nocturna: ${error.body.message}`,
                    variant: 'error',
                });
                this.dispatchEvent(event);
            });
    }
}