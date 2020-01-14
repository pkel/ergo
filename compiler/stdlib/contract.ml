(*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *)

let contract = {xxx|
{"type":"Program","namespace":"org.accordproject.cicero.contract","imports":[],"body":[{"type":"AssetDeclaration","id":{"type":"Identifier","name":"AccordContractState"},"classExtension":null,"idField":{"type":"Identifier","name":"stateId"},"body":{"type":"ClassDeclarationBody","declarations":[{"type":"FieldDeclaration","id":{"type":"Identifier","name":"stateId"},"propertyType":{"name":"String"},"array":null,"regex":null,"default":null,"optional":null,"decorators":[],"location":{"start":{"offset":809,"line":24,"column":3},"end":{"offset":826,"line":25,"column":1}}}],"location":{"start":{"offset":809,"line":24,"column":3},"end":{"offset":826,"line":25,"column":1}}},"abstract":null,"decorators":[],"location":{"start":{"offset":757,"line":23,"column":1},"end":{"offset":827,"line":25,"column":2}}},{"type":"ParticipantDeclaration","id":{"type":"Identifier","name":"AccordParty"},"classExtension":null,"idField":{"type":"Identifier","name":"partyId"},"body":{"type":"ClassDeclarationBody","declarations":[{"type":"FieldDeclaration","id":{"type":"Identifier","name":"partyId"},"propertyType":{"name":"String"},"array":null,"regex":null,"default":null,"optional":null,"decorators":[],"location":{"start":{"offset":907,"line":29,"column":3},"end":{"offset":924,"line":30,"column":1}}}],"location":{"start":{"offset":907,"line":29,"column":3},"end":{"offset":924,"line":30,"column":1}}},"abstract":null,"decorators":[],"location":{"start":{"offset":857,"line":28,"column":1},"end":{"offset":925,"line":30,"column":2}}},{"type":"AssetDeclaration","id":{"type":"Identifier","name":"AccordContract"},"classExtension":null,"idField":{"type":"Identifier","name":"contractId"},"body":{"type":"ClassDeclarationBody","declarations":[{"type":"FieldDeclaration","id":{"type":"Identifier","name":"contractId"},"propertyType":{"name":"String"},"array":null,"regex":null,"default":null,"optional":null,"decorators":[],"location":{"start":{"offset":1049,"line":34,"column":3},"end":{"offset":1071,"line":35,"column":3}}},{"type":"RelationshipDeclaration","id":{"type":"Identifier","name":"parties"},"propertyType":{"type":"Identifier","name":"AccordParty"},"array":"[]","optional":{"type":"Optional"},"decorators":[],"location":{"start":{"offset":1071,"line":35,"column":3},"end":{"offset":1106,"line":36,"column":1}}}],"location":{"start":{"offset":1049,"line":34,"column":3},"end":{"offset":1106,"line":36,"column":1}}},"abstract":["abstract",null],"decorators":[],"location":{"start":{"offset":990,"line":33,"column":1},"end":{"offset":1107,"line":36,"column":2}}},{"type":"AssetDeclaration","id":{"type":"Identifier","name":"AccordClause"},"classExtension":null,"idField":{"type":"Identifier","name":"clauseId"},"body":{"type":"ClassDeclarationBody","declarations":[{"type":"FieldDeclaration","id":{"type":"Identifier","name":"clauseId"},"propertyType":{"name":"String"},"array":null,"regex":null,"default":null,"optional":null,"decorators":[],"location":{"start":{"offset":1224,"line":40,"column":3},"end":{"offset":1242,"line":41,"column":1}}}],"location":{"start":{"offset":1224,"line":40,"column":3},"end":{"offset":1242,"line":41,"column":1}}},"abstract":["abstract",null],"decorators":[],"location":{"start":{"offset":1169,"line":39,"column":1},"end":{"offset":1243,"line":41,"column":2}}}]}
|xxx}